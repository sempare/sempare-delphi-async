unit Sempare.Async.Channel;

interface

uses
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils,
  Sempare.Async;

type
  TChannel<T> = class abstract(TInterfacedObject, IChannel<T>)
  protected
    FLock: TCriticalSection;
    FSendEvent: TEvent;
    FReceiveEvent: TEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Send(const AMessage: T; const ATimeoutMS: uint32 = INFINITE); virtual; abstract;
    function Receive(var AMessage: T): boolean; overload; virtual; abstract;
    function Receive(const ATimeoutMS: uint32 = INFINITE): T; overload; virtual; abstract;
    function HasMessage: boolean; virtual; abstract;
  end;

  ENoMessage = class(Exception);

  TSimpleChannel<T> = class(TChannel<T>)
  private
    FHasMessage: boolean;
    FMessage: T;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Send(const AMessage: T; const ATimeoutMS: uint32 = INFINITE); override;
    function Receive(var AMessage: T): boolean; overload; override;
    function Receive(const ATimeoutMS: uint32 = INFINITE): T; overload; override;
    function HasMessage: boolean; override;
  end;

  TBufferedChannel<T> = class(TChannel<T>)
  private
    FMessage: TQueue<T>;
  public
    constructor Create(const ACapacity: int32 = 100);
    destructor Destroy; override;
    procedure Send(const AMessage: T; const ATimeoutMS: uint32 = INFINITE); override;
    function Receive(var AMessage: T): boolean; overload; override;
    function Receive(const ATimeoutMS: uint32 = INFINITE): T; overload; override;
    function HasMessage: boolean; override;
  end;

implementation

uses
  System.TypInfo;
{ TSimpleChannel<T> }

constructor TSimpleChannel<T>.Create;
begin
  inherited;
  FHasMessage := false;
end;

destructor TSimpleChannel<T>.Destroy;
var
  p: tobject;
begin
  if HasMessage then
  begin
    if PTypeInfo(TypeInfo(T)).Kind = tkClass then
    begin
      move(FMessage, p, sizeof(pointer));
      p.Free;
    end;
  end;
  inherited;
end;

function TSimpleChannel<T>.HasMessage: boolean;
begin
  result := FHasMessage;
end;

function TSimpleChannel<T>.Receive(const ATimeoutMS: uint32): T;
begin
  FLock.Acquire;
  try
    if not FHasMessage then
    begin
      FLock.Release;
      try
        FReceiveEvent.WaitFor();
      finally
        FLock.Acquire;
      end;
    end;
    result := FMessage;
    FSendEvent.SetEvent;
  finally
    FLock.Release;
  end;
end;

function TSimpleChannel<T>.Receive(var AMessage: T): boolean;
begin
  FLock.Acquire;
  try
    if not FHasMessage then
      exit(false);
    AMessage := FMessage;
    FSendEvent.SetEvent;
    exit(true);
  finally
    FLock.Release;
  end;
end;

procedure TSimpleChannel<T>.Send(const AMessage: T; const ATimeoutMS: uint32);
begin
  FLock.Acquire;
  try
    if FHasMessage then
    begin
      FLock.Release;
      try
        FSendEvent.WaitFor(ATimeoutMS);
      finally
        FLock.Acquire;
      end;
    end;
    FSendEvent.ResetEvent;
    FMessage := AMessage;
    FHasMessage := true;
    FReceiveEvent.SetEvent;
  finally
    FLock.Release;
  end;
end;

{ TBufferedChannel<T> }

constructor TBufferedChannel<T>.Create(const ACapacity: int32);
begin
  FMessage := TQueue<T>.Create();
  FMessage.Capacity := ACapacity;
  inherited create;
end;

destructor TBufferedChannel<T>.Destroy;
var
  m: T;
  p: tobject;
begin
  if PTypeInfo(TypeInfo(T)).Kind = tkClass then
  begin
    for m in FMessage do
    begin
      move(m, p, sizeof(pointer));
      p.Free;
    end;
  end;
  FMessage.Free;
  inherited;
end;

function TBufferedChannel<T>.HasMessage: boolean;
begin
  result := FMessage.Count > 0;
end;

function TBufferedChannel<T>.Receive(const ATimeoutMS: uint32): T;
begin
  FLock.Acquire;
  try
    if FMessage.Count = 0 then
    begin
      FLock.Release;
      try
        FReceiveEvent.WaitFor(ATimeoutMS);
      finally
        FLock.Acquire;
      end;
    end;
    result := FMessage.Extract;
    FSendEvent.SetEvent;
  finally
    FLock.Release;
  end;
end;

function TBufferedChannel<T>.Receive(var AMessage: T): boolean;
begin
  FLock.Acquire;
  try
    if FMessage.Count = 0 then
      exit(false);
    AMessage := FMessage.Extract;
    FSendEvent.SetEvent;
    exit(true);
  finally
    FLock.Release;
  end;
end;

procedure TBufferedChannel<T>.Send(const AMessage: T; const ATimeoutMS: uint32);
begin
  FLock.Acquire;
  try
    if FMessage.Count = FMessage.Capacity then
    begin
      FLock.Release;
      try
        FSendEvent.WaitFor(ATimeoutMS);
      finally
        FLock.Acquire;
      end;
    end;
    FSendEvent.ResetEvent;
    FMessage.Enqueue(AMessage);
    FReceiveEvent.SetEvent;
  finally
    FLock.Release;
  end;
end;

{ TChannel<T> }

constructor TChannel<T>.Create;
begin
  FLock := TCriticalSection.Create;
  FSendEvent := TEvent.Create;
  FReceiveEvent := TEvent.Create;

end;

destructor TChannel<T>.Destroy;
begin
  FSendEvent.Free;
  FReceiveEvent.Free;
  FLock.Free;

  inherited;
end;

end.

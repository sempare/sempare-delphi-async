unit Sempare.Async.Promise;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.SyncObjs,
  System.Threading,
  Sempare.Async,
  System.TimeSpan;

type
  TPromiseResult = record
    FValue: TValue;
  strict private
    function GetHasValue: boolean;
  public
    property HasValue: boolean read GetHasValue;
    function AsType<T>: T;
  end;

  TPromiseItem = class;

  TPromise = class(TInterfacedObject, IPromise)
  private
    FValue: TValue;
    FCurrentOffset: integer;
    FCurrentTask: ITask;
    FItems: TObjectList<TPromiseItem>;
    FWaitFor: TEvent;
    function FirstItem: TPromiseItem;
    function LastItem: TPromiseItem;
    function GetItem(const AOffset: integer): TPromiseItem;
    function GetItemWithExceptionHandler(const AOffset: integer): TPromiseItem;
    function IsLast(const AOffset: integer): boolean;
    procedure Cancel;
  public
    function Add: TPromiseItem;
    constructor Create();
    destructor Destroy; override;

    function Catch(const AMethod: TPromiseExceptionHandler): IPromise;
    function Next(): TPromiseThen;
    function Start: TPromiseComplete;
    procedure Wait(const ATimeout: TTimespan); overload;
    procedure Wait(const ATimeout: cardinal); overload;
    property Value: TValue read FValue write FValue;
  end;

  _TEventHandlerBase_ = class;

  TPromiseItem = class
  private
    FOffset: integer;
    FPromise: TPromise;
    FExceptionHandler: TPromiseExceptionHandler;
    FHandler: _TEventHandlerBase_;

    procedure Start();
    procedure Init(const EventHandler: _TEventHandlerBase_); overload;

  public
    constructor Create(const APromise: TPromise);
    destructor Destroy; override;

    // ideally init would not be required as generics are not allowed on constructors.
    procedure Init<T>(const AMethod: TPromiseMethod<T>; const AOption: TPromiseOption; const APrev: IPromise = nil); overload;
    procedure Init(const AMethod: TPromiseMethodProc; const AOption: TPromiseOption; const APrev: IPromise = nil); overload;
    procedure Init<TIn, T>(const AMethod: TPromiseMethodArg<TIn, T>; const AOption: TPromiseOption; const APrev: IPromise = nil); overload;
    procedure Init<TIn>(const AMethod: TPromiseMethodProcArg<TIn>; const AOption: TPromiseOption; const APrev: IPromise = nil); overload;

    procedure Catch(const AMethod: TPromiseExceptionHandler);
    function Next(): TPromiseThen;
  end;

  _TEventHandlerBase_ = class abstract
  public
    procedure HandleEvent(sender: TObject); virtual; abstract;
  end;

  _TEventHandlerBase_<TMethod> = class abstract(_TEventHandlerBase_)
  private
    procedure ActuallyHandleEvent(sender: TObject);
  protected
    FPromise: TPromiseItem;
    FMethod: TMethod;
    FOption: TPromiseOption;
  protected
    procedure DoHandleEvent(sender: TPromiseItem); virtual; abstract;
  public
    constructor Create(const APromise: TPromiseItem; const AMethod: TMethod; const AOption: TPromiseOption);
    procedure HandleEvent(sender: TObject); override;
  end;

  _TEventHandler_<T> = class(_TEventHandlerBase_ < TPromiseMethod < T >> )
  protected
    procedure DoHandleEvent(sender: TPromiseItem); override;
  end;

  _TEventHandler_<TIn, T> = class(_TEventHandlerBase_ < TPromiseMethodArg < TIn, T >> )
  protected
    procedure DoHandleEvent(sender: TPromiseItem); override;
  end;

  _TEventHandler_ = class(_TEventHandlerBase_<TPromiseMethodProc>)
  protected
    procedure DoHandleEvent(sender: TPromiseItem); override;
  end;

  _TEventHandlerArg_<TIn> = class(_TEventHandlerBase_ < TPromiseMethodProcArg < TIn >> )
  protected
    procedure DoHandleEvent(sender: TPromiseItem); override;
  end;

implementation

{ TPromiseResult }

function TPromiseResult.AsType<T>: T;
begin
  result := FValue.AsType<T>;
end;

function TPromiseResult.GetHasValue: boolean;
begin
  result := not FValue.IsEmpty;
end;

{ TPromise }

procedure TPromiseItem.Catch(const AMethod: TPromiseExceptionHandler);
begin
  FExceptionHandler := AMethod;
end;

constructor TPromiseItem.Create(const APromise: TPromise);
begin
  FPromise := APromise;
end;

destructor TPromiseItem.Destroy;
begin
  FPromise := nil;
  if FHandler <> nil then
  begin
    FHandler.free;
    FHandler := nil;
  end;
  inherited;
end;

procedure TPromiseItem.Init<T>(const AMethod: TPromiseMethod<T>; const AOption: TPromiseOption; const APrev: IPromise);
begin
  Init(_TEventHandler_<T>.Create(self, AMethod, AOption));
end;

procedure TPromiseItem.Init(const EventHandler: _TEventHandlerBase_);
begin
  FOffset := FPromise.FCurrentOffset;
  inc(FPromise.FCurrentOffset);
  FHandler := EventHandler;
end;

procedure TPromiseItem.Init<TIn, T>(const AMethod: TPromiseMethodArg<TIn, T>; const AOption: TPromiseOption; const APrev: IPromise);
begin
  Init(_TEventHandler_<TIn, T>.Create(self, AMethod, AOption));
end;

procedure TPromiseItem.Init<TIn>(const AMethod: TPromiseMethodProcArg<TIn>; const AOption: TPromiseOption; const APrev: IPromise);
begin
  Init(_TEventHandlerArg_<TIn>.Create(self, AMethod, AOption));
end;

procedure TPromiseItem.Start();
begin
  FPromise.FCurrentTask := TTask.Create(self, FHandler.HandleEvent);
  FPromise.FCurrentTask.Start;
end;

procedure TPromiseItem.Init(const AMethod: TPromiseMethodProc; const AOption: TPromiseOption; const APrev: IPromise);
begin
  Init(_TEventHandler_.Create(self, AMethod, AOption));
end;

function TPromiseItem.Next(): TPromiseThen;
begin
  result := TPromiseThen.Create(self.FPromise);
end;

{ TEventHandler<T> }

procedure _TEventHandler_<T>.DoHandleEvent(sender: TPromiseItem);
begin
  sender.FPromise.FValue := TValue.From<T>(FMethod);
end;

{ TPromise }

function TPromise.Add: TPromiseItem;
begin
  result := TPromiseItem.Create(self);
  FItems.Add(result);
end;

procedure TPromise.Cancel;
var
  status: ttaskstatus;
begin
  status := ttaskstatus.Created;
  if (FCurrentTask <> nil) then
  begin
    status := FCurrentTask.status;
    if not(status in [ttaskstatus.Completed, ttaskstatus.Canceled]) then
      FCurrentTask.Cancel;
  end;
  FWaitFor.SetEvent;
  if status = ttaskstatus.Created then
    raise EOperationCancelled.Create('terminating promise chain');
end;

function TPromise.Catch(const AMethod: TPromiseExceptionHandler): IPromise;
var
  item: TPromiseItem;
begin
  item := LastItem;
  if item <> nil then
    item.Catch(AMethod);
  result := self;
end;

constructor TPromise.Create;
begin
  FItems := TObjectList<TPromiseItem>.Create();
  FWaitFor := TEvent.Create;
end;

destructor TPromise.Destroy;
begin
  FItems.free;
  FWaitFor.free;
  inherited;
end;

function TPromise.FirstItem: TPromiseItem;
begin
  result := GetItem(0);
end;

function TPromise.GetItem(const AOffset: integer): TPromiseItem;
begin
  if AOffset + 1 > FItems.Count then
    exit(nil);
  result := FItems[AOffset];
end;

function TPromise.GetItemWithExceptionHandler(const AOffset: integer): TPromiseItem;
var
  i: integer;
begin
  for i := AOffset + 1 to FItems.Count - 1 do
  begin
    result := FItems[i];
    if assigned(result.FExceptionHandler) then
      exit;
  end;
  result := nil;
end;

function TPromise.IsLast(const AOffset: integer): boolean;
begin
  result := FItems.Count - 1 = AOffset;
end;

function TPromise.LastItem: TPromiseItem;
begin
  if FItems.Count = 0 then
    exit(nil);
  result := FItems[FItems.Count - 1];
end;

function TPromise.Next: TPromiseThen;
begin
  result := TPromiseThen.Create(self);
end;

function TPromise.Start: TPromiseComplete;
begin
  self.FirstItem.Start;
  result := TPromiseComplete.Create(self);
end;

procedure TPromise.Wait(const ATimeout: TTimespan);
begin
  FWaitFor.WaitFor(ATimeout);
end;

procedure TPromise.Wait(const ATimeout: cardinal);
begin
  FWaitFor.WaitFor(ATimeout);
end;

{ _TEventHandler_<TIn, T> }

procedure _TEventHandler_<TIn, T>.DoHandleEvent(sender: TPromiseItem);
begin
  sender.FPromise.FValue := TValue.From<T>(FMethod(sender.FPromise.FValue.AsType<TIn>()));
end;

{ _TEventHandler_ }

procedure _TEventHandler_.DoHandleEvent(sender: TPromiseItem);
begin
  FMethod();
end;

{ _TEventHandlerArg_<TIn> }

procedure _TEventHandlerArg_<TIn>.DoHandleEvent(sender: TPromiseItem);
begin
  FMethod(sender.FPromise.FValue.AsType<TIn>());
end;

{ _TEventHandlerBase_<TMethod> }

procedure _TEventHandlerBase_<TMethod>.ActuallyHandleEvent(sender: TObject);
var
  current, Next: TPromiseItem;
begin
  current := TPromiseItem(sender);
  try
    DoHandleEvent(current);
    Next := current.FPromise.GetItem(current.FOffset + 1);
    if Next <> nil then
      Next.Start
    else
      current.FPromise.FWaitFor.SetEvent;
  except
    on e: Exception do
    begin
      Next := current.FPromise.GetItemWithExceptionHandler(current.FOffset);
      if Next = nil then
        raise EOperationCancelled.Create(e.Message);
      current.FPromise.Cancel;
      Next.FExceptionHandler(e);
    end;
  end;
end;

constructor _TEventHandlerBase_<TMethod>.Create(const APromise: TPromiseItem; const AMethod: TMethod; const AOption: TPromiseOption);
begin
  FPromise := APromise;
  FMethod := AMethod;
  FOption := AOption;
end;

procedure _TEventHandlerBase_<TMethod>.HandleEvent(sender: TObject);

begin
  if FOption = SyncUI then
    TThread.Synchronize(nil,
      procedure
      begin
        ActuallyHandleEvent(sender);
      end)
  else
    ActuallyHandleEvent(sender);
end;

end.

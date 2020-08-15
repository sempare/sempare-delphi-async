unit Sempare.Async.Promise;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
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

  TPromise = class(TInterfacedObject, IPromise)
  private
    FValue: TValue;
    FTask: ITask;
    FNext: IPromise;
    FPrev: IPromise;
    FExceptionHandler: TPromiseExceptionHandler;
    FHandler: TObject;
    procedure StartChain;
    procedure StartNext;
    procedure SkipToEventHandler(const AException: Exception);
    procedure SetPrev(const APrev: IPromise); inline;
  public
    constructor Create();
    destructor Destroy; override;

    procedure Cancel;

    // ideally init would not be required as generics are not allowed on constructors.
    procedure Init<T>(const AMethod: TPromiseMethod<T>; const AOption: TPromiseArg; const APrev: IPromise = nil); overload;
    procedure Init(const AMethod: TPromiseMethodProc; const AOption: TPromiseArg; const APrev: IPromise = nil); overload;
    procedure Init<TIn, T>(const AMethod: TPromiseMethodArg<TIn, T>; const AOption: TPromiseArg; const APrev: IPromise = nil); overload;
    procedure Init<TIn>(const AMethod: TPromiseMethodProcArg<TIn>; const AOption: TPromiseArg; const APrev: IPromise = nil); overload;

    function Catch(const AMethod: TPromiseExceptionHandler): IPromise;
    function Next(): TPromiseThen;
    function Get<T>: T;
    function Start: TPromiseComplete;

    property Task: ITask read FTask;
  end;

  _TEventHandlerBase_<TMethod> = class abstract
  private
    procedure ActuallyHandleEvent(sender: TObject);
  protected
    FPromise: IPromise;
    FMethod: TMethod;
    FOption: TPromiseArg;
  protected
    procedure DoHandleEvent(sender: TPromise); virtual; abstract;
  public
    constructor Create(const APromise: IPromise; const AMethod: TMethod; const AOption: TPromiseArg);
    procedure HandleEvent(sender: TObject);
  end;

  _TEventHandler_<T> = class(_TEventHandlerBase_ < TPromiseMethod < T >> )
  protected
    procedure DoHandleEvent(sender: TPromise); override;
  end;

  _TEventHandler_<TIn, T> = class(_TEventHandlerBase_ < TPromiseMethodArg < TIn, T >> )
  protected
    procedure DoHandleEvent(sender: TPromise); override;
  end;

  _TEventHandler_ = class(_TEventHandlerBase_<TPromiseMethodProc>)
  protected
    procedure DoHandleEvent(sender: TPromise); override;
  end;

  _TEventHandlerArg_<TIn> = class(_TEventHandlerBase_ < TPromiseMethodProcArg < TIn >> )
  protected
    procedure DoHandleEvent(sender: TPromise); override;
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

procedure TPromise.Cancel;
var
  status: ttaskstatus;
begin
  status := ttaskstatus.Created;
  if (FTask <> nil) then
  begin
    status := FTask.status;
    if not(status in [ttaskstatus.Completed, ttaskstatus.Canceled]) then
      FTask.Cancel;
  end;
  if status = ttaskstatus.Created then
    raise EOperationCancelled.Create('terminating promise chain');
end;

function TPromise.Catch(const AMethod: TPromiseExceptionHandler): IPromise;
begin
  FExceptionHandler := AMethod;
  result := self;
end;

constructor TPromise.Create;
begin
end;

destructor TPromise.Destroy;
begin
  FTask := nil;
  FNext := nil;
  FPrev := nil;
  if FHandler <> nil then
  begin
    FHandler.Free;
    FHandler := nil;
  end;
  inherited;
end;

function TPromise.Get<T>: T;
begin
  StartChain;
  FTask.Wait();
end;

procedure TPromise.Init<T>(const AMethod: TPromiseMethod<T>; const AOption: TPromiseArg; const APrev: IPromise);
var
  handler: _TEventHandler_<T>;
begin
  handler := _TEventHandler_<T>.Create(self, AMethod, AOption);
  FHandler := handler;
  FTask := TTask.Create(self, handler.HandleEvent);
  SetPrev(APrev);
end;

procedure TPromise.Init<TIn, T>(const AMethod: TPromiseMethodArg<TIn, T>; const AOption: TPromiseArg; const APrev: IPromise);
var
  helper: _TEventHandler_<TIn, T>;
begin
  helper := _TEventHandler_<TIn, T>.Create(self, AMethod, AOption);
  FHandler := helper;
  FTask := TTask.Create(self, helper.HandleEvent);
  SetPrev(APrev);
end;

procedure TPromise.Init<TIn>(const AMethod: TPromiseMethodProcArg<TIn>; const AOption: TPromiseArg; const APrev: IPromise);
var
  helper: _TEventHandlerArg_<TIn>;
begin
  helper := _TEventHandlerArg_<TIn>.Create(self, AMethod, AOption);
  FHandler := helper;
  FTask := TTask.Create(self, helper.HandleEvent);
  SetPrev(APrev);
end;

procedure TPromise.SetPrev(const APrev: IPromise);
begin
  FPrev := APrev;
  if APrev <> nil then
    TPromise(APrev).FNext := self;
end;

procedure TPromise.SkipToEventHandler(const AException: Exception);
var
  h, n: TPromise;
  last: IPromise;
begin
  h := self;
  last := self;
  while (last <> nil) and (TPromise(last).FNext <> nil) do
    last := TPromise(last).FNext;

  while (h <> nil) and not assigned(h.FExceptionHandler) do
  begin
    n := TPromise(h.FNext);
    TPromise(h).FNext := nil;
    h := n;
    h.FPrev := nil;
  end;
  if h.FPrev <> nil then
    TPromise(h.FPrev).FNext := nil;
  h.FPrev := nil;
  if assigned(h.FExceptionHandler) then
  begin
    try
      h.FExceptionHandler(AException);
    finally
      if last <> nil then
        TPromise(last).Cancel;
    end;
  end
  else
    raise AException;
end;

function TPromise.Start: TPromiseComplete;
begin
  result := TPromiseComplete.Create(self);
  StartChain;
end;

procedure TPromise.StartChain;
var
  f: TPromise;
begin
  f := self;
  while f.FPrev <> nil do
    f := TPromise(f.FPrev);
  f.FTask.Start;
end;

procedure TPromise.StartNext;
begin
  if FNext <> nil then
  begin
    TPromise(FNext).FValue := FValue;
    TPromise(FNext).FTask.Start;
    TPromise(FNext).FPrev := nil;
    FNext := nil;
  end;
end;

procedure TPromise.Init(const AMethod: TPromiseMethodProc; const AOption: TPromiseArg; const APrev: IPromise);
var
  helper: _TEventHandler_;
begin
  helper := _TEventHandler_.Create(self, AMethod, AOption);
  FHandler := helper;
  FTask := TTask.Create(self, helper.HandleEvent);
  SetPrev(APrev);
end;

function TPromise.Next(): TPromiseThen;
begin
  result := TPromiseThen.Create(self);
end;

{ TEventHandler<T> }

procedure _TEventHandler_<T>.DoHandleEvent(sender: TPromise);
begin
  sender.FValue := TValue.From<T>(FMethod);
end;

{ _TEventHandler_<TIn, T> }

procedure _TEventHandler_<TIn, T>.DoHandleEvent(sender: TPromise);
begin
  sender.FValue := TValue.From<T>(FMethod(sender.FValue.AsType<TIn>()));
end;

{ _TEventHandler_ }

procedure _TEventHandler_.DoHandleEvent(sender: TPromise);
begin
  FMethod();
end;

{ _TEventHandlerArg_<TIn> }

procedure _TEventHandlerArg_<TIn>.DoHandleEvent(sender: TPromise);
begin
  FMethod(sender.FValue.AsType<TIn>());
end;

{ _TEventHandlerBase_<TMethod> }

procedure _TEventHandlerBase_<TMethod>.ActuallyHandleEvent(sender: TObject);
var
  p: TPromise;
begin
  p := TPromise(sender);
  try
    DoHandleEvent(p);
    p.StartNext;
  except
    on e: Exception do
      p.SkipToEventHandler(e);
  end;
end;

constructor _TEventHandlerBase_<TMethod>.Create(const APromise: IPromise; const AMethod: TMethod; const AOption: TPromiseArg);
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

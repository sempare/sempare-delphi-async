unit Sempare.Async;

interface

uses
  System.SysUtils,
  System.TimeSpan,
  System.Rtti;

type
  // import ttimespan so users don't have to manually import it
  TTimespan = System.TimeSpan.TTimespan;

  IChannel<T> = interface
    ['{B256D710-A1C7-48B5-AFF6-BBD7FBB3B8CA}']

    procedure Send(const AMessage: T; const ATimeoutMS: uint32 = INFINITE);
    function Receive(var AMessage: T): boolean; overload;
    function Receive(const ATimeoutMS: uint32 = INFINITE): T; overload;
    function HasMessage: boolean;
  end;

  Channel = class
  public
    class function Create<T>(const ABufferSize: int32 = 1): IChannel<T>; static;
  end;

  IWaitGroup = interface
    ['{C4EAD2FA-6392-4064-B004-9749590E88FF}']
    procedure Add(const ADelta: integer);
    procedure Done();
    procedure Wait(Timeout: cardinal = INFINITE);
  end;

  TPromiseMethod<T> = reference to function: T;
  TPromiseMethodProc = reference to procedure;
  TPromiseMethodArg<TIn, T> = reference to function(const AArg: TIn): T;
  TPromiseMethodProcArg<TIn> = reference to procedure(const AArg: TIn);
  TPromiseExceptionHandler = reference to procedure(const AException: Exception);

  IPromise = interface;

  TPromiseThen = record
  strict private
    FPromise: IPromise;
  public
    constructor Create(const APromise: IPromise);
    function Apply<T>(const AMethod: TPromiseMethod<T>): IPromise; overload;
    function Apply(const AMethod: TPromiseMethodProc): IPromise; overload;
    function Apply<TIn, T>(const AMethod: TPromiseMethodArg<TIn, T>): IPromise; overload;
    function Apply<T>(const AMethod: TPromiseMethodProcArg<T>): IPromise; overload;
  end;

  TPromiseComplete = record
  strict private
    FPromise: IPromise;

  public
    constructor Create(const APromise: IPromise);
    procedure Wait(const ADurationMS: cardinal = INFINITE); overload;
    procedure Wait(const ATimespan: TTimespan); overload;
  end;

  IPromise = interface
    ['{3ACE02F6-CCDB-4249-92A4-6A69E9F2E2ED}']

    function Start(): TPromiseComplete;
    function Catch(const AMethod: TPromiseExceptionHandler): IPromise;
    function Next(): TPromiseThen;
  end;

  Promise = record
  public
    class function Apply<T>(const AMethod: TPromiseMethod<T>): IPromise; overload; static;
    class function Apply(const AMethod: TPromiseMethodProc): IPromise; overload; static;
  end;

  WaitGroup = record
  public
    class function Create(const ACount: integer = 0): IWaitGroup; static;
  end;

implementation

uses
  Sempare.Async.Channel,
  Sempare.Async.Promise,
  Sempare.Async.WaitGroup;

class function WaitGroup.Create(const ACount: integer): IWaitGroup;
begin
  result := TWaitGroup.Create;
  if ACount > 0 then
    result.Add(ACount);
end;

{ Channel<T> }

class function Channel.Create<T>(const ABufferSize: int32): IChannel<T>;
begin
  if ABufferSize = 1 then
    result := TSimpleChannel<T>.Create
  else
    result := TBufferedChannel<T>.Create(ABufferSize);
end;

{ Promise }

class function Promise.Apply(const AMethod: TPromiseMethodProc): IPromise;
var
  p: TPromise;
begin
  p := TPromise.Create();
  p.Init(AMethod);
  result := p;
end;

class function Promise.Apply<T>(const AMethod: TPromiseMethod<T>): IPromise;
var
  p: TPromise;
begin
  p := TPromise.Create();
  p.Init<T>(AMethod);
  result := p;
end;

{ TPromiseComplete }

constructor TPromiseComplete.Create(const APromise: IPromise);
begin
  FPromise := APromise;
end;

procedure TPromiseComplete.Wait(const ATimespan: TTimespan);
begin
  TPromise(FPromise).Task.Wait(ATimespan);
end;

procedure TPromiseComplete.Wait(const ADurationMS: cardinal);
begin
  TPromise(FPromise).Task.Wait(ADurationMS);
end;

{ TPromiseThen }

constructor TPromiseThen.Create(

  const APromise: IPromise);
begin
  FPromise := APromise;
end;

function TPromiseThen.Apply(

  const AMethod: TPromiseMethodProc): IPromise;
var
  Promise: TPromise;
begin
  Promise := TPromise.Create();
  Promise.Init(AMethod, TPromise(FPromise));
  result := Promise;
end;

function TPromiseThen.Apply<T>(const AMethod: TPromiseMethodProcArg<T>): IPromise;
var
  Promise: TPromise;
begin
  Promise := TPromise.Create();
  Promise.Init<T>(AMethod, FPromise);
  result := Promise;
end;

function TPromiseThen.Apply<T>(const AMethod: TPromiseMethod<T>): IPromise;
var
  Promise: TPromise;
begin
  Promise := TPromise.Create();
  Promise.Init<T>(AMethod, FPromise);
  result := Promise;
end;

function TPromiseThen.Apply<TIn, T>(const AMethod: TPromiseMethodArg<TIn, T>): IPromise;
var
  Promise: TPromise;
begin
  Promise := TPromise.Create();
  Promise.Init<TIn, T>(AMethod, FPromise);
  result := Promise;
end;

end.

unit Sempare.Async.WaitGroup;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Sempare.Async;

type
  TWaitGroupError = class(Exception);

  TWaitGroup = class(TInterfacedObject, IWaitGroup)
  private
    FCount: integer;
    Fevent: TEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const ADelta: integer);
    procedure Done();
    procedure Wait(Timeout: cardinal = INFINITE);
  end;

implementation

{ TWaitGroup }

procedure TWaitGroup.Add(const ADelta: integer);
begin
  if FCount + ADelta < 0 then
    raise TWaitGroupError.Create('negative count');
  AtomicIncrement(FCount, ADelta);
end;

constructor TWaitGroup.Create;
begin
  Fevent := TEvent.Create;
end;

destructor TWaitGroup.Destroy;
begin
  Fevent.Free;
  inherited;
end;

procedure TWaitGroup.Done;
begin
  Add(-1);
  Fevent.SetEvent;
end;

procedure TWaitGroup.Wait(Timeout: cardinal);
begin
  while FCount > 0 do
  begin
    Fevent.WaitFor(Timeout);
  end;
end;

end.

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
    FEvent: TCountdownEvent;
    // we subtract 1 on the first add as the CountdownEvent starts with 1 (so it doesn't signal on initialisation)
    FSub1: boolean;
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
var
  delta: integer;
begin
  delta := ADelta;
  if not FSub1 then
  begin
    FSub1 := true;
    dec(delta);
  end;
  FEvent.AddCount(delta);
end;

constructor TWaitGroup.Create;
begin
  FEvent := TCountdownEvent.Create();
  FSub1 := false;
end;

destructor TWaitGroup.Destroy;
begin
  FEvent.Free;
  inherited;
end;

procedure TWaitGroup.Done;
begin
  FEvent.Signal();
end;

procedure TWaitGroup.Wait(Timeout: cardinal);
begin
  FEvent.WaitFor(Timeout);
end;

end.

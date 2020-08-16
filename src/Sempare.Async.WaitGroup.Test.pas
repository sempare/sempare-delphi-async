unit Sempare.Async.WaitGroup.Test;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  TWaitGroupTests = class
  public
    [Test]
    procedure TestWaitGroup;
  end;

implementation

uses
  Sempare.Async.WaitGroup,
  Sempare.Async;

{ TWaitGroupTests }

procedure TWaitGroupTests.TestWaitGroup;
var
  wg: IWaitGroup;
  i: integer;
  p1, p2: ipromise;
begin
  wg := WaitGroup.Create;
  wg.Add(2);
  p1 := promise.Apply(
    procedure
    begin
      Sleep(15);
      inc(i);
      wg.Done;
    end);
  p2 := promise.Apply(
    procedure
    begin
      inc(i);
      Sleep(15);
      wg.Done;
    end);
  p1.Start;
  p2.Start;
  wg.Wait();
  Assert.AreEqual(2, i);
end;

initialization

TDUnitX.RegisterTestFixture(TWaitGroupTests);

end.

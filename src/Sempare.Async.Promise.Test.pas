unit Sempare.Async.Promise.Test;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  TPromiseTests = class
  public
    [Test, MaxTime(1000)]
    procedure TestBasic;

    [Test, MaxTime(1000)]
    procedure TestReturnValue;

    [Test, MaxTime(1000)]
    procedure TestException;
  end;

implementation

uses

  Sempare.Async;

{ TMyTestObject }

procedure TPromiseTests.TestException;
var
  i: integer;
  ok: boolean;
begin
  ok := false;
  Promise //
    .Apply(
    procedure
    begin
      raise Exception.Create('boo');
    end) //
    .Next.Apply(
    procedure
    begin
      inc(i);
    end) //
    .Next.Apply(
    procedure
    begin
      inc(i);
    end).Catch(
    procedure(const AException: Exception)
    begin
      inc(i);
      ok := true;
    end) //
    .Start //
    .Wait;
  assert.IsTrue(ok);
  assert.AreEqual(1, i);
end;

procedure TPromiseTests.TestReturnValue;
var
  i: integer;
  p: ipromise;
begin
  p := Promise //
    .Apply<string>(
    function: string
    begin
      inc(i);
      result := 'hello world';
    end) //
    .Next.Apply<string>(
    procedure(const AValue: string)
    begin
      inc(i);
    end) //
    .Next.Apply<string, string>(
    function(const AValue: string): string
    begin
      inc(i);
      result := '## ' + AValue;
    end) //
    .Next.Apply<string>(
    procedure(const AValue: string)
    begin
      inc(i);
    end).Next.Apply<string, integer>(
    function(const AValue: string): integer
    begin
      inc(i);
      result := length(AValue)
    end).Next.Apply(
    procedure()
    begin
      inc(i);
    end).Next.Apply<integer>(
    procedure(const AValue: integer)
    begin
      inc(i);
      assert.AreEqual(14, AValue);
    end);

  p.Start //
    .Wait;

  assert.AreEqual(7, i);
end;

procedure TPromiseTests.TestBasic;
var
  i: integer;
begin
  Promise.Apply(
    procedure
    begin
      inc(i);
    end).Next.Apply(
    procedure
    begin
      inc(i);
    end).Start.Wait;
  assert.AreEqual(2, i);
end;

initialization

TDUnitX.RegisterTestFixture(TPromiseTests);

end.

unit Sempare.Async.Channel.Test;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  TChannelTests = class
  public
    [Test]
    procedure TestBasic;

    [Test]
    procedure TestBasicBlocking;

    [Test]
    procedure TestBasicNonBlocking;

    [Test]
    procedure TestBuffered;

  end;

implementation

uses
  Sempare.Async,
  Sempare.Async.Promise,
  Sempare.Async.Channel;

{ TChannelTests }

procedure TChannelTests.TestBasic;
var
  c: IChannel<integer>;
begin
  c := Channel.create<integer>();
  c.Send(123);
  assert.AreEqual(123, c.Receive(123));
end;

procedure TChannelTests.TestBasicBlocking;
var
  c: IChannel<integer>;
  p: TPromiseComplete;
begin
  c := Channel.create<integer>();
  p := Promise.Apply(
    procedure
    begin
      assert.AreEqual(123, c.Receive(123));
    end).Start;
  c.Send(123);
  c.Send(345);
  p.Wait();
  assert.AreEqual(345, c.Receive(345));
end;

procedure TChannelTests.TestBasicNonBlocking;
var
  c: IChannel<integer>;
  i: integer;
begin
  c := Channel.create<integer>();
  assert.IsFalse(c.Receive(i));
  c.Send(123);
  assert.istrue(c.Receive(i));
  assert.AreEqual(123, i);
end;

procedure TChannelTests.TestBuffered;
var
  c: IChannel<integer>;
begin
  c := Channel.Create<integer>();
  c.Send(123);
  assert.AreEqual(123, c.Receive(123));
end;

initialization

TDUnitX.RegisterTestFixture(TChannelTests);

end.

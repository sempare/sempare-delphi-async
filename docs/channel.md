# Channel

Similar to Go channels used for message passing.

## Single Message Buffer 

### Receive

Send blocks when the buffer is full.
Receive blocks if another no message is available.

```
var ch := Channel.Create<integer>(1);
ch.Send(1);
Promise.Apply(procedure
begin
	Sleep(1000); // to bypass blocking
	ch.Send(1, 1000); // send with 1000ms timeout
end).Start();
var i := ch.Receive()
```

### Receive with timeout

```
var i : integer;
var ch := Channel.Create<integer>(1);
ch.Send(1);
var received := ch.Receive(i, 1000) // 1000 ms
```
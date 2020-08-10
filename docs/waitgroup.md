# WaitGroup

WaitGroup has 3 methods:
	- add   - increments a count by delta
	- done  - decrements a count by 1
	- wait  - waits for count to be 0
	
Similar to Go WaitGroup

```
var wg := WaitGroup.Create(2);
wg.Add(2);
var Promise.Apply(procedure 
begin
  wg.Done();
end)
.Next.Apply(procedure 
begin
  wg.Done();
end)
.Next.Apply(procedure 
begin
  wg.Done();
end)
.Next.Apply(procedure 
begin
  wg.Done();
end)
.Start;

wg.Wait();
```
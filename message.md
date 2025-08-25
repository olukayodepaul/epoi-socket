## Proto Testing

````
awareness = %Dartmessaging.Awareness{
  from: "a@domain.com/aaaaa1",
  last_seen: 11223344506,   # depends on the int64 value
  status: "ONLINE",
  latitude: 1.0,
  longitude: 2.0
}
binary = Dartmessaging.Awareness.encode(awareness)
hex = Base.encode16(binary, case: :upper)
```

````

# module natsv

 Client lib for nats.io. 

## Contents
- [MSG](#MSG)
- [Nats](#Nats)
  - [connect](#connect)
  - [close](#close)
  - [sub](#sub)
  - [usub](#usub)
  - [publish](#publish)

## MSG
```v
struct MSG {
mut:
	subid string
pub mut:
	subject string
	msg     string
	size    int
}
```


[[Return to contents]](#Contents)

## Nats
```v
struct Nats {
pub mut:
	verbose  bool
	pedantic bool
	echo     bool
mut:
	url       string
	user      string
	pass      string
	lastid    int
	handlers  shared map[string]SubjectHandler
	inch      chan string
	inmsg     chan MSG
	info      json2.Any
	connected bool
	c         net.TcpConn
}
```


[[Return to contents]](#Contents)

## connect
```v
fn (mut n Nats) connect(url string, user string, pass string) ?
```
 Connect to nats server. 

[[Return to contents]](#Contents)

## close
```v
fn (mut n Nats) close() ?
```
 Close connection. 

[[Return to contents]](#Contents)

## sub
```v
fn (mut n Nats) sub(subject string, cb SubjectHandler) ?string
```
 Subscribe to subject. 

[[Return to contents]](#Contents)

## usub
```v
fn (mut n Nats) usub(subid string) ?
```
 Unsubscribe to subject. 

[[Return to contents]](#Contents)

## publish
```v
fn (mut n Nats) publish(subject string, msg string) ?
```
 Publish message. 

[[Return to contents]](#Contents)

#### Powered by vdoc. Generated on: 2 Aug 2021 11:14:31

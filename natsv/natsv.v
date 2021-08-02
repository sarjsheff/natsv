module natsv

// Client lib for nats.io.
import net
import x.json2
import strconv
// import os

// struct INFO {
// 	server_id     string
// 	version       string
// 	golang        string   [json: 'go']
// 	host          string
// 	port          int
// 	max_payload   i64
// 	proto         int
// 	client_id     u64
// 	auth_required bool
// 	tls_required  bool
// 	tls_verify    bool
// 	connect_urls  []string
// 	ldm           bool
// }
// fn (mut p INFO) from_json(f json2.Any) {
//     obj := f.as_map()
//     for k, v in obj {
//         match k {
//             'name' { p.name = v.str() }
//             'age' { p.age = v.int() }
//             'pets' { p.pets = v.arr().map(it.str()) }
//             else {}
//         }
//     }
// }
struct CONNECT {
	verbose      bool
	pedantic     bool
	tls_required bool
	auth_token   string
	user         string
	pass         string
	name         string
	lang         string
	version      string
	protocol     int
	echo         bool
	sig          string
	jwt          string
}

pub struct MSG {
mut:
	subid string
pub mut:
	subject string
	msg     string
	size    int
}

fn lerr(msg string) {
	println(msg)
}

fn log(msg string) {
	$if debug {
		println(msg)
	}
}

pub struct Nats {
pub mut:
	verbose  bool
	pedantic bool
	echo     bool // may set only if INFO.proto > 0
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

type SubjectHandler = fn (MSG)

fn (mut nats Nats) router() {
	log('Start router')
	for {
		m := <-nats.inmsg
		log('<route $m.subject $m.subid')
		rlock nats.handlers {
			if m.subid in nats.handlers {
				fnn := nats.handlers[m.subid]
				fnn(m)
			}
		}

		log(m.str())
	}
	log('Exit router')
}

fn (mut nats Nats) worker() {
	log('Start worker')
	for {
		s := <-nats.inch
		if s == ('PING\r\n') {
			log('pong')
			nats.c.write('PONG\r\n'.bytes()) or { lerr('write error: $err') }
		} else {
			log(s)
		}
	}
	log('Exit worker')
}

fn (mut nats Nats) reader() {
	log('Start reader')
	for {
		nats.c.wait_for_read() or {
			lerr('Error wait socket read $err')
			return
		}
		// println('read')
		mut s := nats.c.read_line()
		if s.starts_with('MSG ') {
			args := s.split(' ')
			mut m := MSG{}
			m.size = strconv.atoi(args.pop().replace('\r\n', '')) or {
				log(err.msg)
				0
			}
			m.subid = args.pop()
			m.subject = args.pop()
			m.msg = ''

			log('msg size $m.size')
			if m.size > 0 {
				for m.size > m.msg.len {
					nats.c.wait_for_read() or {
						lerr('Error wait socket read $err')
						return
					}
					tmp := nats.c.read_line()
					if tmp.len > 1 {
						r := tmp.len - 2
						m.msg = m.msg + tmp[..r]
					} else {
						println('.')
					}
				}
			}
			nats.inmsg <- mut m
		} else if s.len == 0 {
			lerr('Connection close')
			return
		} else if s.starts_with('-ERR') {
			print(s)
		} else if s.starts_with('+OK') {
			// print(s)
		} else {
			nats.inch <- s
		}
	}
	log('Exit reader')
}

// Connect to nats server.
pub fn (mut n Nats) connect(url string, user string, pass string) ? {
	mut c := net.dial_tcp(url) or { return error('Connect error') }

	c.set_read_timeout(net.infinite_timeout)
	// c.set_write_deadline(net.no_deadline)

	c.wait_for_read() ?

	s := c.read_line()
	if s.starts_with('INFO ') {
		info := json2.raw_decode(s[5..]) ?
		log(info.str())

		mut con := map[string]json2.Any{}
		con['verbose'] = n.verbose
		con['pedantic'] = n.pedantic
		con['lang'] = 'vlang'
		con['version'] = '0.0.0'
		if info.as_map()['auth_required'].bool() {
			con['user'] = user
			con['pass'] = pass
		}
		c.wait_for_write() ?
		c.write(('CONNECT ' + con.str() + '\r\n').bytes()) ?
		c.wait_for_read() ?
		ret := c.read_line()
		log(ret)
		if !ret.starts_with('+OK') {
			return error(ret)
		}

		n.info = info
		n.c = c
		n.connected = true

		n.inmsg = chan MSG{}
		n.inch = chan string{}

		// n.handlers = map[string]SubjectHandler{}
		go n.worker()
		go n.router()
		go n.reader()
	} else {
		return error('Connect error in protocol')
	}
}

// Close connection.
pub fn (mut n Nats) close() ? {
	n.c.close() ?
}

// Subscribe to subject.
pub fn (mut n Nats) sub(subject string, cb SubjectHandler) ?string {
	mut l := n.lastid
	// rlock n.handlers {
	// 	l = n.handlers.len
	// }
	n.c.write('SUB $subject $l\r\n'.bytes()) ?
	lock n.handlers {
		n.handlers[n.lastid.str()] = cb
	}
	defer {
		n.lastid++
	}
	return n.lastid.str()
}

// Unsubscribe to subject.
pub fn (mut n Nats) usub(subid string) ? {
	n.c.write('UNSUB $subid\r\n'.bytes()) ?
	lock n.handlers {
		n.handlers.delete(subid)
	}
}

// Publish message.
pub fn (mut n Nats) publish(subject string, msg string) ? {
	n.c.write('PUB $subject $msg.len\r\n$msg\r\n'.bytes()) ?
}

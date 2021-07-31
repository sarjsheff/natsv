module main

import net
import x.json2
import time
import strconv
import os

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

struct MSG {
mut:
	subid   string
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

struct Nats {
pub mut:
	verbose  bool
	pedantic bool
	echo     bool // may set only if INFO.proto > 0
mut:
	lastid    int
	handlers  map[string]SubjectHandler
	inch      chan string
	inmsg     chan MSG
	info      json2.Any
	connected bool
	c         net.TcpConn
}

type SubjectHandler = fn (MSG)

fn (mut n Nats) close() ? {
	n.c.close() ?
}

fn (mut n Nats) sub(subject string, cb SubjectHandler) ?int {
	n.c.write('sub $subject $n.handlers.len\n'.bytes()) ?
	n.handlers[n.lastid.str()] = cb
	defer {
		n.lastid++
	}
	return n.lastid
}

fn (mut nats Nats) reader() {
	log('Start reader')
	for {
		// println(nats.c.read_line())
		nats.c.wait_for_read() or {
			lerr('Error wait socket read $err')
			return
		}
		mut s := nats.c.read_line()
		if s.starts_with('MSG ') {
			args := s.split(' ')
			mut m := MSG{}
			m.size = strconv.atoi(args.pop().replace('\r\n', '')) or {
				log(err)
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
		} else {
			nats.inch <- s
		}
	}
	log('Exit reader')
}

fn (mut nats Nats) router() {
	log('Start router')
	for {
		// println("<read")
		m := <-nats.inmsg

		fnn := nats.handlers[m.subid]
		fnn(m)

		log(m.str())
	}
	log('Exit router')
}

fn (mut nats Nats) worker() {
	log('Start worker')
	for {
		// println("<read")
		s := <-nats.inch
		if s == ('PING\r\n') {
			log('pong')
			nats.c.write('pong\n'.bytes())
		} else {
			log(s)
		}
	}
	log('Exit worker')
}

fn (mut n Nats) connect(url string, user string, pass string) ? {
	mut c := net.dial_tcp(url) or { return error('Connect error') }

	c.set_read_timeout(net.infinite_timeout)
	c.set_write_deadline(net.no_deadline)

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
		c.write(('CONNECT ' + con.str() + '\n').bytes()) ?
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

		n.handlers = map[string]SubjectHandler{}
		go n.worker()
		go n.router()
		go n.reader()
	} else {
		return error('Connect error in protocol')
	}
}

fn main() {
	if os.args.len > 3 {
		mut nats := Nats{
			verbose: true
		}
		println('Connect')
		nats.connect(os.args[1], os.args[2], os.args[3]) or {
			lerr(err)
			return
		}
		println('Subscribe')
		nats.sub('>', fn (m MSG) {
			println('>>>> $m.subject')
		}) or {
			lerr('subscribe err')
			return
		}
		nats.sub('hikmqtt.Int.>', fn (m MSG) {
			println('<<<<')
		}) or {
			lerr('sub err')
			return
		}

		for {
			time.sleep(1)
			// print(".")
		}
		println('Close')
		nats.close()
	} else {
		lerr('Wrong number of arguments.')
	}
}

module main

import natsv
import time
import os

fn lerr(msg string) {
	println(msg)
}

fn log(msg string) {
	$if debug {
		println(msg)
	}
}

fn main() {
	if os.args.len > 3 {
		mut nats := natsv.Nats{
			verbose: true
		}
		println('Connect')
		nats.connect(os.args[1], os.args[2], os.args[3]) or {
			lerr(err.msg)
			return
		}
		println('Subscribe')
		subid := nats.sub('>', fn (m natsv.MSG) {
			println('>>>> $m.subject')
		}) or {
			lerr('subscribe err $err')
			return
		}
		time.sleep(5 * time.second)
		nats.usub(subid) or { println('$err') }

		nats.sub('vlang.tick.test', fn (m natsv.MSG) {
			println('<<<< $m.msg')
		}) or {
			lerr('sub err $err')
			return
		}
		nats.publish('vlang.tick.test', '1234567890'.repeat(10000)) or { println('$err') }

		for {
			nats.publish('vlang.tick.test', 'tick') or { println('$err') }
			time.sleep(5 * time.second)
			// print(".")
		}
		println('Close')
		nats.close() or { println('$err') }
	} else {
		lerr('Wrong number of arguments.')
	}
}

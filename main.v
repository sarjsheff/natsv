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
		nats.sub('>', fn (m natsv.MSG) {
			println('>>>> $m.subject')
		}) or {
			lerr('subscribe err $err')
			return
		}
		subid := nats.sub('hikmqtt.Int.>', fn (m natsv.MSG) {
			println('<<<<')
		}) or {
			lerr('sub err $err')
			return
		}
		time.sleep(5 * time.second)
		nats.usub(subid) or { println('$err') }
		
		for {
			time.sleep(5 * time.second)	
			// print(".")
		}
		println('Close')
		nats.close() or { println('$err') }
	} else {
		lerr('Wrong number of arguments.')
	}
}

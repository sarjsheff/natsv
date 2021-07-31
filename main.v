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
			lerr(err)
			return
		}
		println('Subscribe')
		nats.sub('>', fn (m natsv.MSG) {
			println('>>>> $m.subject')
		}) or {
			lerr('subscribe err')
			return
		}
		nats.sub('hikmqtt.Int.>', fn (m natsv.MSG) {
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

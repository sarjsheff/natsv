module main

import natsv
import time
import os
import net.http
import net.html
import json

fn lerr(msg string) {
	println(msg)
}

fn log(msg string) {
	$if debug {
		println(msg)
	}
}

struct Day {
mut:
	dt       string
	isnight  bool
	status   string
	temp     string
	fallout  string
	wind     string
	pressure string
}

fn getweather() ?string {
	resp := http.get('https://meteoinfo.ru/forecasts/russia/moscow-area/kolomna') ?
	mut doc := html.parse(resp.text)
	tbody := doc.get_tag_by_attribute_value('id', 'div_4_1')[0].children[1].children[0]
	mut data := []Day{}
	for i, td in tbody.children[0].children {
		if i > 0 {
			data << Day{
				dt: td.text()
				isnight: false
				status: tbody.children[1].children[i].children[0].children[0].attributes['title']
				temp: tbody.children[2].children[i].text()
				fallout: tbody.children[4].children[i].text()
				wind: tbody.children[5].children[i].text()
				pressure: tbody.children[6].children[i].text()
			}
			if i > 1 {
				data << Day{
					dt: td.text()
					isnight: true
					status: tbody.children[7].children[i].children[0].children[0].attributes['title']
					temp: tbody.children[8].children[i].text()
					fallout: tbody.children[10].children[i].text()
					wind: tbody.children[11].children[i].text()
					pressure: tbody.children[12].children[i].text()
				}
			}
		}
	}

	return json.encode(data)
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
		for {
			nats.publish('weather.meteoinfo.kolomna', getweather() ?) or { println('$err') }
			time.sleep(5 * time.second)
			// print(".")
		}
	} else {
		lerr('Wrong number of arguments.')
	}
}

fn test() {
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

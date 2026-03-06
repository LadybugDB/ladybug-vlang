#!/usr/bin/env -S v run

import build
import os

const app_name = 'lbug'

mut context := build.context(
	default: 'all'
)

context.task(
	name: 'download_lbug'
	run: fn (self build.Task) ! {
		println('❯ bash scripts/download-liblbug.sh')
		if os.system('bash scripts/download-liblbug.sh') != 0 {
			return error('download-liblbug failed')
		}
	}
)

context.task(
	name: 'copy_header'
	run: fn (self build.Task) ! {
		println('❯ cp lib/lbug.h ladybug/')
		if os.system('cp lib/lbug.h ladybug/') != 0 {
			return error('copy header failed')
		}
	}
)

context.task(
	name: 'build_app'
	run: fn (self build.Task) ! {
		println('❯ v -o ${app_name} shell-v/main.v')
		if os.system('v -o ${app_name} shell-v/main.v') != 0 {
			return error('build app failed')
		}
	}
)

context.task(
	name:    'all'
	depends: ['download_lbug', 'copy_header', 'build_app']
	run:     fn (self build.Task) ! {}
)

context.run()

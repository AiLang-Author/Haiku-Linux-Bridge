#!/bin/sh
# Combined fork+execve+poll. Expect PIPELINEOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/pipeline.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_pipeline ==="
	/boot/home/sys_compat_run /boot/home/hello_pipeline
	echo PIPELINE_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== pipeline.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/pipeline_out.txt" || true
echo RUN_PIPELINE_DONE

RESULTS_DIR=$1

cat ${RESULTS_DIR}/cpu-1.json | cut -d ";" -f1 | cut -d "\"" -f2 > ${RESULTS_DIR}/cpu-time.txt
cat ${RESULTS_DIR}/cpu-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/cpu-val.txt

cat ${RESULTS_DIR}/mem_usage-1.json | cut -d ";" -f1 | cut -d "\"" -f2 > ${RESULTS_DIR}/mem-time.txt
cat ${RESULTS_DIR}/mem_usage-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/mem-val.txt 

cat ${RESULTS_DIR}/server_errors-1.json | cut -d ";" -f1 | cut -d "\"" -f2 > ${RESULTS_DIR}/err-time.txt
cat ${RESULTS_DIR}/server_errors-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/err-val.txt

cat ${RESULTS_DIR}/app_timer_sum-1.json | cut -d ";" -f1 | cut -d "\"" -f2 > ${RESULTS_DIR}/app-sum-time.txt
cat ${RESULTS_DIR}/app_timer_sum-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/app-sum-val.txt

cat ${RESULTS_DIR}/app_timer_count-1.json | cut -d ";" -f1 | cut -d "\"" -f2 > ${RESULTS_DIR}/app-count-time.txt
cat ${RESULTS_DIR}/app_timer_count-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/app-count-val.txt

cat ${RESULTS_DIR}/app_timer_max-1.json | cut -d ";" -f1 | cut -d "\"" -f2 > ${RESULTS_DIR}/app-max-time.txt
cat ${RESULTS_DIR}/app_timer_max-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/app-max-val.txt

#paste cpu-time.txt cpu-val.txt mem-time.txt mem-val.txt err-time.txt err-val.txt app-sum-time.txt app-sum-val.txt app-count-time.txt app-count-val.txt app-max-time.txt app-max-val.txt

cat ${RESULTS_DIR}/app_timer_count_rate_1m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/app_count_1to30m.txt
cat ${RESULTS_DIR}/app_timer_count_rate_3m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_count_1to30m.txt
cat ${RESULTS_DIR}/app_timer_count_rate_5m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_count_1to30m.txt
cat ${RESULTS_DIR}/app_timer_count_rate_7m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_count_1to30m.txt
cat ${RESULTS_DIR}/app_timer_count_rate_9m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_count_1to30m.txt
cat ${RESULTS_DIR}/app_timer_count_rate_15m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_count_1to30m.txt
cat ${RESULTS_DIR}/app_timer_count_rate_30m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_count_1to30m.txt

cat ${RESULTS_DIR}/app_timer_sum_rate_1m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 > ${RESULTS_DIR}/app_sum_1to30m.txt
cat ${RESULTS_DIR}/app_timer_sum_rate_3m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_sum_1to30m.txt
cat ${RESULTS_DIR}/app_timer_sum_rate_5m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_sum_1to30m.txt
cat ${RESULTS_DIR}/app_timer_sum_rate_7m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_sum_1to30m.txt
cat ${RESULTS_DIR}/app_timer_sum_rate_9m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_sum_1to30m.txt
cat ${RESULTS_DIR}/app_timer_sum_rate_15m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_sum_1to30m.txt
cat ${RESULTS_DIR}/app_timer_sum_rate_30m-1.json | cut -d ";" -f4 | cut -d "\"" -f1 >> ${RESULTS_DIR}/app_sum_1to30m.txt

#paste app_count_1to30m.txt app_sum_1to30m.txt

awk 'NR == 1 {origin = $1} {$1 = $1 - origin; print}' ${RESULTS_DIR}/app-sum-time.txt > ${RESULTS_DIR}/app-sum-time-diff.txt
awk 'NR > 1 { print $0 - prev } { prev = $0 }' ${RESULTS_DIR}/app-sum-val.txt > ${RESULTS_DIR}/app-sum-val-diff.txt 
paste ${RESULTS_DIR}/app-sum-time-diff.txt ${RESULTS_DIR}/app-sum-val-diff.txt > ${RESULTS_DIR}/app-sum-diff.txt

awk 'NR == 1 {origin = $1} {$1 = $1 - origin; print}' ${RESULTS_DIR}/app-count-time.txt > ${RESULTS_DIR}/app-count-time-diff.txt
awk 'NR > 1 { print $0 - prev } { prev = $0 }' ${RESULTS_DIR}/app-count-val.txt > ${RESULTS_DIR}/app-count-val-diff.txt
paste ${RESULTS_DIR}/app-count-time-diff.txt ${RESULTS_DIR}/app-count-val-diff.txt > ${RESULTS_DIR}/app-count-diff.txt

awk 'NR == 1 {origin = $1} {$1 = $1 - origin; print}' ${RESULTS_DIR}/app-max-time.txt > ${RESULTS_DIR}/app-max-time-diff.txt
paste ${RESULTS_DIR}/app-max-time-diff.txt ${RESULTS_DIR}/app-max-val.txt > ${RESULTS_DIR}/app-max.txt
awk '!a[$2]++' ${RESULTS_DIR}/app-max.txt > ${RESULTS_DIR}/app-max-uniq.txt

awk '{for(i=2;i<=NF;i++){if($i+0 < 1) next}} 1' ${RESULTS_DIR}/app-sum-diff.txt > ${RESULTS_DIR}/app-sum-sort.txt
awk '{for(i=2;i<=NF;i++){if($i+0 < 1) next}} 1' ${RESULTS_DIR}/app-count-diff.txt > ${RESULTS_DIR}/app-count-sort.txt

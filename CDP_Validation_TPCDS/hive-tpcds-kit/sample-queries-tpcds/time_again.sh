APP_DIR=`dirname $0`
CURR_DIR=`pwd`

cd $APP_DIR

ITERATIONS=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scale)
      shift
      SCALE=$1
      shift
      ;;
    --dir)
      shift
      OUTPUT_DIR=$1
      shift
      ;;
    --iterations)
      shift
      ITERATIONS=$1
      shift
      ;;
  esac
done

echo "     Scale: ${SCALE}"
echo "       Dir: ${OUTPUT_DIR}"
echo "Iterations: ${ITERATIONS}"

for (( i=1; i<=$ITERATIONS; i++ ))
do
  echo "Iteration #: ${i}"
  . ./time.sh --db tpcds_bin_partitioned_managed_orc_$SCALE --dir $OUTPUT_DIR
  . ./time.sh --db tpcds_bin_not_partitioned_managed_orc_$SCALE --dir $OUTPUT_DIR
  . ./time.sh --db tpcds_bin_partitioned_external_orc_$SCALE --dir $OUTPUT_DIR
  . ./time.sh --db tpcds_bin_not_partitioned_external_orc_$SCALE --dir $OUTPUT_DIR
done

echo "Done"
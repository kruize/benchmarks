NAMESPACE=$1

echo "Running ttm job with 512 context length for weather and eletricity datasets"
echo "==========================================================================="
# To run a ttm job with 512 context length
./run_ttm_job.sh job.yaml training-ttm $NAMESPACE
echo ""
echo "Completed ttm job with 512 context length for weather and eletricity datasets"
echo "==========================================================================="
echo

echo "Running ttm job with 1024 context length for weather and eletricity datasets"
echo "==========================================================================="
# To run a ttm job with 1024 context length
./run_ttm_job.sh job_1024.yaml training-ttm-1024 $NAMESPACE
echo ""
echo "Completed ttm job with 1024 context length for weather and eletricity datasets"
echo "==========================================================================="
echo

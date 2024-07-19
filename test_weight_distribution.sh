# test-weight-distribution.sh
blue_count=0
green_count=0

for i in {1..10}
do
  response=$(curl --resolve myapp.local:8080:127.0.0.1 http://myapp.local:8080)
  if [[ $response == "I am blue" ]]; then
    ((blue_count++))
  elif [[ $response == "I am green" ]]; then
    ((green_count++))
  fi
done

echo "Blue app response count: $blue_count"
echo "Green app response count: $green_count"


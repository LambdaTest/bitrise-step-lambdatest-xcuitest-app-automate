#!/bin/bash
set -ex
echo "uploading app ipa to LambdaTest"
upload_app_response="$(curl --location --request POST https://$lambdatest_username:$lambdatest_access_key@manual-api.lambdatest.com/app/uploadFramework --form type="xcuit-ios" --form appFile=@$app_ipa_path)"

app_url=$(echo "$upload_app_response" | jq .app_id)

echo "uploading test ipa/zip to LambdaTest"
upload_test_response="$(curl --location --request POST https://$lambdatest_username:$lambdatest_access_key@manual-api.lambdatest.com/app/uploadFramework --form type="xcuit-ios" --form appFile=@$test_ipa_path)"
test_url=$(echo "$upload_test_response" | jq .app_id)

echo "starting automated tests"
json=$( jq -n \
                --argjson app_url $app_url \
                --argjson test_url $test_url \
                --argjson devices ["$lambdatest_device_list"] \
                --arg build "$lambdatest_build_name" \
                --arg queue_timeout "$lambdatest_queue_timeout" \
                --arg idle_timeout "$lambdatest_idle_timeout" \
                --arg geo_location "$lambdatest_geo_location" \
                --arg tunnel "$lambdatest_tunnel" \
                --arg tunnel_identifier "$lambdatest_tunnel_identifier" \
                --arg device_logs "$lambdatest_device_logs" \
                --arg network_logs "$lambdatest_network_logs" \
                --arg video "$lambdatest_video" \
                '{app: $app_url, testSuite: $test_url, device: $devices, build: $build, queueTimeout: $queue_timeout | tonumber, idleTimeout: $idle_timeout | tonumber, geoLocation: $geo_location, tunnel: $tunnel | test("true"), tunnelIdentifier: $tunnel_identifier, devicelog: $device_logs | test("true"), network: $network_logs | test("true"), video: $video | test("true")}')
run_test_response="$(curl --location --request POST https://$lambdatest_username:$lambdatest_access_key@mobile-api.lambdatest.com/framework/v1/xcui/build --header "Content-Type: application/json" --data-raw \ "$json")"
build_id=$(echo "$run_test_response" | jq .buildId)

echo "build id: ${build_id}"

array=(`echo $build_id | sed 's/,/\n/g'`)
unset array[$(( ${#array[@]} - 1 ))]
unset array[0]
printf -v builds_string ',%s' "${array[@]}"
builds_string=${builds_string:1} 
builds_array="["${builds_string}"]" 

envman add --key LAMBDATEST_BUILD_ID --value "${builds_array}"
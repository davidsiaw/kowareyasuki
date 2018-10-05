
num = 3

for i in 1..num
	`docker kill mysql#{i}`
	`docker rm mysql#{i}`

	`rm -rf cfg#{i}/data1`
	`rm -rf cfg#{i}/data2`
end

`docker network rm mysqlnet`

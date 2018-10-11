require "./num"

for i in 1..num
	`docker kill mysql#{i}`
	`docker rm mysql#{i}`

	`rm -rf cfg#{i}`
end

`rm -rf global`
`docker network rm mysqlnet`

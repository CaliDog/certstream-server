build-frontend:
	if [ -d "dist/" ]; then rm -rf dist/; fi
	docker build -t certstream-frontend .
	docker run --rm -it -v $$(pwd)/dist/:/app/dist/ certstream-frontend npm run build
	docker rmi certstream-frontend
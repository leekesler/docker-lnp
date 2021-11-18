# Docker

### Design a functional Linux, Nginx and PHP stack docker file such that you can run the following command:

`docker exec <container_name> bash -c "<path to php> -i"`

### You will need to do the following:

1. Start with Alpine Linux as the base
2. Do not import any other Dockerfile
3. Compile Nginx 1.17.x and PHP 7.4.x from the latest source, and include at least the
modules to support redis and xdebug functionality
4. Add a docker compose file which allows host direct access to the PHP and Nginx logs
through shared volumes


### Getting started
This is an Alpine, PHP 7.4, Nginx stack.

To build:

`docker-compose up -d --build`

To run:

`docker-compose up`

To test:

`docker exec web bash -c "php -i"`
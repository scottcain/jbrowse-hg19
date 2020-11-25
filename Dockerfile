# JBrowse

#
# This docker file uses multistage builds, where the first stage (named 'build')
# gets lots of prereqs, checks out git repos and runs the setup script. The
# resulting image is over 2GB and can be deleted after building. The second
# stage (called 'production') then copies files from the first stage and
# results in a image that is just over 100MB.
#
# Also, note the change to the initial parent image: there is now a jbrowse-buildenv
# image at docker hub
#
# Finally, a short note about how this JBrowse instance is configured to work:
# This instance is served up by nginx and only the configuration files and
# javascript files are served from here.  All of the data are stored in an AWS
# S3 bucket.  This separation makes development and production issues easier
# (in my opinion)

FROM gmod/jbrowse-buildenv:latest as build

# Actually JBrowse code; can bump the release tag and rebuild to get new versions
RUN git clone --single-branch --branch dev https://github.com/GMOD/jbrowse.git

RUN git clone --single-branch --branch main https://github.com/scottcain/jbrowse-hg19.git

RUN mkdir /usr/share/nginx/html/jbrowse

RUN rm /usr/share/nginx/html/index.html && rm /usr/share/nginx/html/50x.html && cp -r /jbrowse/* /usr/share/nginx/html/jbrowse && \
    cp /jbrowse/.htaccess /usr/share/nginx/html/jbrowse/.htaccess && \
    cp /jbrowse-hg19/jbrowse/jbrowse.conf /usr/share/nginx/html/jbrowse && \
    cp -r /jbrowse-hg19/jbrowse/data /usr/share/nginx/html/jbrowse

WORKDIR /usr/share/nginx/html/jbrowse

#RUN npm install yarn
#RUN ./node_modules/.bin/yarn
#RUN JBROWSE_BUILD_MIN=1 ./node_modules/.bin/yarn build

#in the near futre, this setup command will be replaced with the yarn commands above
#to make building faster
RUN ./setup.sh -f

#this is the magic that makes the production container so very small
FROM nginx:latest as production

COPY --from=build /usr/share/nginx/html/jbrowse/dist /usr/share/nginx/html/jbrowse/dist
COPY --from=build /usr/share/nginx/html/jbrowse/browser /usr/share/nginx/html/jbrowse/browser
COPY --from=build /usr/share/nginx/html/jbrowse/css /usr/share/nginx/html/jbrowse/css
COPY --from=build /usr/share/nginx/html/jbrowse/data /usr/share/nginx/html/jbrowse/data
COPY --from=build /usr/share/nginx/html/jbrowse/img /usr/share/nginx/html/jbrowse/img
COPY --from=build /usr/share/nginx/html/jbrowse/index.html /usr/share/nginx/html/jbrowse/index.html
COPY --from=build /usr/share/nginx/html/jbrowse/jbrowse_conf.json /usr/share/nginx/html/jbrowse/jbrowse_conf.json
COPY --from=build /usr/share/nginx/html/jbrowse/jbrowse.conf /usr/share/nginx/html/jbrowse/jbrowse.conf
COPY --from=build /usr/share/nginx/html/jbrowse/LICENSE /usr/share/nginx/html/jbrowse/LICENSE
COPY --from=build /usr/share/nginx/html/jbrowse/plugins /usr/share/nginx/html/jbrowse/plugins
COPY --from=build /usr/share/nginx/html/jbrowse/site.webmanifest /usr/share/nginx/html/jbrowse/site.webmanifest
COPY --from=build /usr/share/nginx/html/jbrowse/.htaccess /usr/share/nginx/html/jbrowse/.htaccess


VOLUME /data
COPY docker-entrypoint.sh /
CMD ["/docker-entrypoint.sh"]

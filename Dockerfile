FROM alpine:3.6
MAINTAINER Sean Cheung <theoxuanx@gmail.com>

RUN apk add --no-cache openjdk8-jre tini su-exec

ENV STACK 6.0.0

RUN apk add --no-cache libzmq bash nodejs supervisor openssl
RUN mkdir -p /usr/local/lib \
	&& ln -s /usr/lib/*/libzmq.so.3 /usr/local/lib/libzmq.so
RUN apk add --no-cache -t .build-deps wget ca-certificates \
	&& set -x \
	&& cd /tmp \
	&& echo "Download Elastic Stack ======================================================" \
	&& echo "Download Elasticsearch..." \
	&& wget --progress=bar:force -O elasticsearch-$STACK.tar.gz https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$STACK.tar.gz \
	&& tar -xzf elasticsearch-$STACK.tar.gz \
	&& mv elasticsearch-$STACK /usr/share/elasticsearch \
	&& echo "Download Logstash..." \
	&& wget --progress=bar:force -O logstash-$STACK.tar.gz https://artifacts.elastic.co/downloads/logstash/logstash-$STACK.tar.gz \
	&& tar -xzf logstash-$STACK.tar.gz \
	&& mv logstash-$STACK /usr/share/logstash \
	&& echo "Download Kibana..." \
	&& wget --progress=bar:force -O kibana-$STACK.tar.gz https://artifacts.elastic.co/downloads/kibana/kibana-$STACK-linux-x86_64.tar.gz \
	&& tar -xzf kibana-$STACK.tar.gz \
	&& mv kibana-$STACK-linux-x86_64 /usr/share/kibana \
	&& echo "Configure [Elasticsearch] ===================================================" \
	&& for path in \
		/usr/share/elasticsearch/data \
		/usr/share/elasticsearch/logs \
		/usr/share/elasticsearch/config \
		/usr/share/elasticsearch/config/scripts \
		/usr/share/elasticsearch/plugins \
	; do \
	mkdir -p "$path"; \
	done \
	&& echo "Configure [Logstash] ========================================================" \
	&& mkdir -p /etc/logstash/conf.d \
	&& if [ -f "$LS_SETTINGS_DIR/logstash.yml" ]; then \
			sed -ri 's!^(path.log|path.config):!#&!g' "$LS_SETTINGS_DIR/logstash.yml"; \
		fi \
	&& echo "Configure [Kibana] ==========================================================" \
	# the default "server.host" is "localhost" in 5+
	&& sed -ri "s!^(\#\s*)?(server\.host:).*!\2 '0.0.0.0'!" /usr/share/kibana/config/kibana.yml \
	&& grep -q "^server\.host: '0.0.0.0'\$" /usr/share/kibana/config/kibana.yml \
	# usr alpine nodejs and not bundled version
	&& bundled='NODE="${DIR}/node/bin/node"' \
	&& apline_node='NODE="/usr/bin/node"' \
	&& sed -i "s|$bundled|$apline_node|g" /usr/share/kibana/bin/kibana-plugin \
	&& sed -i "s|$bundled|$apline_node|g" /usr/share/kibana/bin/kibana \
	&& rm -rf /usr/share/kibana/node \
	&& echo "Create elstack user..." \
	&& adduser -DH -s /sbin/nologin elstack \
	&& chown -R elstack:elstack /usr/share/elasticsearch \
	&& chown -R elstack:elstack /usr/share/logstash \
	&& chown -R elstack:elstack /usr/share/kibana \
    && echo "Download X-Pack..." \
    && wget --progress=bar:force -O /tmp/x-pack-$STACK.zip https://artifacts.elastic.co/downloads/packs/x-pack/x-pack-$STACK.zip \
    && echo "Installing X-Pack for Elasticsearch..." \
    && /usr/share/elasticsearch/bin/elasticsearch-plugin install file:///tmp/x-pack-$STACK.zip \
    && echo "Installing X-Pack for Logstash..." \
    && /usr/share/logstash/bin/logstash-plugin install file:///tmp/x-pack-$STACK.zip \
    && echo "Installing X-Pack for Kibana..." \
    && /usr/share/kibana/bin/kibana-plugin install file:///tmp/x-pack-$STACK.zip \
	&& echo "Clean Up..." \
	&& rm -rf /tmp/* \
	&& apk del --purge .build-deps

ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV PATH /usr/share/logstash/bin:$PATH
ENV PATH /usr/share/kibana/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk

# necessary for 5.0+ (overriden via "--path.settings", ignored by < 5.0)
ENV LS_SETTINGS_DIR /etc/logstash

# Add configs
COPY elasticsearch.yml /usr/share/elasticsearch/config/
COPY logstash.yml /etc/logstash/
COPY logstash.conf /etc/logstash/conf.d/
COPY supervisord.conf /etc/supervisor/

# Add entrypoints
COPY elasticsearch-entrypoint.sh /
COPY logstash-entrypoint.sh /
COPY kibana-entrypoint.sh /

VOLUME ["/usr/share/elasticsearch/data"]
VOLUME ["/etc/logstash/conf.d"]

EXPOSE 5601 9200 9300

CMD ["/sbin/tini","--","/usr/bin/supervisord","-c", "/etc/supervisor/supervisord.conf"]
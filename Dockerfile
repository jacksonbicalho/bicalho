ARG DOCKER_WORK_DIR_DEFAULT=/usr/src/app
ARG NODE_VERSION=18.18.2
ARG YARN_VERSION=1.22.19

# #############################
# # base: build for Base
# #############################
FROM node:${NODE_VERSION}-alpine As base

LABEL package=bicalho

ARG DOCKER_LABEL_KEY
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}

ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}

LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

ARG NODE_ENV
ENV NODE_ENV ${NODE_ENV:-builder}

ARG DOCKER_USER_UID
ENV DOCKER_USER_UID ${DOCKER_USER_UID:-36891}

ARG DOCKER_USER_NAME ${DOCKER_USER_NAME}
ENV DOCKER_USER_NAME ${DOCKER_USER_NAME}

ARG NPM_TOKEN ${NPM_TOKEN}
ENV NPM_TOKEN ${NPM_TOKEN}

ARG YARN_TOKEN ${YARN_TOKEN}
ENV YARN_TOKEN ${YARN_TOKEN}

ARG DOCKER_WORK_DIR
ENV DOCKER_WORK_DIR ${DOCKER_WORK_DIR:-$DOCKER_WORK_DIR_DEFAULT}

COPY \
  package.json* \
  yarn.lock* \
  .yarnrc* \
  .npmrc* \
  ./

RUN rm -rf ./cache

RUN rm -rf /usr/local/bin/yarn \
  && rm -rf /usr/local/bin/yarnpkg \
  && npm uninstall --loglevel warn --global pnpm \
  && deluser --remove-home node \
  && apk --no-cache update \
  && apk --no-cache upgrade \
  && apk add --no-cache \
  nano \
  openssh \
  bash \
  bash-completion \
  make \
  python3 \
  curl \
  git \
  && apk add --no-cache \
  --virtual builds-deps \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -snf /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -snf /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz \
  && yarn --version \
  && curl -sfL RUN curl -sf https://gobinaries.com/tj/node-prune | bash -s -- -b /usr/local/bin/ \
  && apk del builds-deps \
  && rm -rf /var/cache/apk/*

RUN mkdir -p /etc/skel/

RUN <<EOF cat >> /etc/skel/.bashrc
source /etc/bash/bash_completion.sh
set autologout = 30
set prompt = "$ "
set history = 0
set ignoreeof
EOF

RUN cp /etc/skel/.bashrc /etc/skel/.profile


RUN addgroup -S ${DOCKER_USER_NAME} -g ${DOCKER_USER_UID} \
  && adduser -S -G ${DOCKER_USER_NAME} -u ${DOCKER_USER_UID} ${DOCKER_USER_NAME} \
  --shell /bin/bash \
  --home /home/${DOCKER_USER_NAME} \
  -k /etc/skel

RUN cat /etc/profile > /home/${DOCKER_USER_NAME}/.profile

WORKDIR ${DOCKER_WORK_DIR}

COPY . ./

COPY ./docker/*.sh /usr/local/bin/
RUN chmod -R +x /usr/local/bin/

RUN if [ "$TARGET" != "publish" ]; then install-dependencies.sh; fi;

RUN ls -l \
  && ls /usr/local/bin/ \
  && /usr/local/bin/node-prune \
  && chown -R ${DOCKER_USER_NAME}:${DOCKER_USER_NAME} ./

RUN --mount=type=secret,id=npmrc,target=${DOCKER_WORK_DIR}/.npmrc

ENV NODE_REPL_HISTORY=''

USER ${DOCKER_USER_NAME}

ARG GIT_CONFIG_USER_NAME
ENV GIT_CONFIG_USER_NAME ${GIT_CONFIG_USER_NAME}

ARG GIT_CONFIG_USER_EMAIL
ENV GIT_CONFIG_USER_EMAIL ${GIT_CONFIG_USER_EMAIL}

ARG GITHUB_AUTH
ENV GITHUB_AUTH ${GITHUB_AUTH}

ARG GIT_PRIVATE_KEY
ENV GIT_PRIVATE_KEY ${GIT_PRIVATE_KEY}

RUN mkdir -p /home/${DOCKER_USER_NAME}/.ssh && \
  chmod 0700 /home/${DOCKER_USER_NAME}/.ssh && \
  ssh-keyscan github.com > /home/${DOCKER_USER_NAME}/.ssh/known_hosts && \
  echo "${GIT_PRIVATE_KEY}" > /home/${DOCKER_USER_NAME}/.ssh/id_rsa && \
  chmod 600 /home/${DOCKER_USER_NAME}/.ssh/id_rsa

RUN git config --global user.name "${GIT_CONFIG_USER_NAME}" \
  && git config --global user.email "${GIT_CONFIG_USER_EMAIL}" \
  && git config --global core.editor "nano"

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "node" ]


#####################################
# development
#####################################
FROM base as dev
ARG DOCKER_LABEL_KEY
ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}
LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

ENV NODE_ENV=development

ARG SERVER_PORT
ENV SERVER_PORT ${SERVER_PORT}


ARG NPM_TOKEN
ENV NPM_TOKEN ${NPM_TOKEN}

ARG YARN_TOKEN
ENV YARN_TOKEN ${YARN_TOKEN}

EXPOSE ${SERVER_PORT}


##################################
# publish
##################################
FROM base as publish
ARG DOCKER_LABEL_KEY
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}

ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}

LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

ENV NODE_ENV=development

ARG NPM_TOKEN
ENV NPM_TOKEN ${NPM_TOKEN}

ARG YARN_TOKEN
ENV YARN_TOKEN ${YARN_TOKEN}

COPY --from=base --chown=${DOCKER_USER_NAME}:${DOCKER_USER_NAME} /app/package.json /app/package.json
COPY --from=base --chown=${DOCKER_USER_NAME}:${DOCKER_USER_NAME} /app/yarn.lock /app/yarn.lock



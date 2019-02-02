public: archetypes content data layouts static themes
	hugo

.PHONY: deploy
deploy: public
	rsync -r public/* defn@defn.io:~/www

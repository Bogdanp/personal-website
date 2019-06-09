public: archetypes content data layouts themes
	hugo

.PHONY: deploy
deploy: public
	rsync -avz --delete public/* defn:~/www

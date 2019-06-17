public: archetypes content data layouts static themes
	hugo

.PHONY: deploy
deploy: public
	rsync -avz --delete public/* defn:~/www

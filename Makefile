public: archetypes content static themes
	hugo

.PHONY: deploy
deploy: public
	rsync -avz --delete public/* defn:~/www

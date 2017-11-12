public: archetypes content data layouts static themes
	hugo

.PHONY: deploy
deploy: public
	gcloud app deploy --project defn-166408 app.yaml

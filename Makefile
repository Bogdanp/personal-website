public: archetypes content data layouts static templates
	hugo

.PHONY: deploy
deploy: public
	gcloud app deploy --project defn-166408 app.yaml

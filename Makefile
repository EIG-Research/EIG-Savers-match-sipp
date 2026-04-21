.PHONY: brain-sync brain-check brain-simulate literature-check maintenance-check

brain-sync:
	bash Infrastructure/scripts/manage_generated_copies.sh sync

brain-check:
	bash Infrastructure/scripts/manage_generated_copies.sh check

brain-simulate:
	bash Infrastructure/scripts/simulate_cps_review_smoke_test.sh

literature-check:
	python3 Infrastructure/scripts/validate_literature_catalog.py

maintenance-check:
	$(MAKE) brain-check
	$(MAKE) literature-check
	python3 Infrastructure/scripts/check_internal_path_references.py
	python3 Infrastructure/scripts/check_catalog_staleness.py

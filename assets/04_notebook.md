# 4. Interactive session in Colab Enterprise Notebook

This step demonstrates how users can interact with data using Colab Enterprise Notebooks in BigQuery, covering:
* Multi engine support in BigQuery: how to query data using BigQuery SQL, Python and PySpark
* Interaction with the migrated data via BigLake External tables (`customers`, `transactions`), and newly created tables by Spark in BigQuery (`revenue_report`).

All the instructions are provided in the notebook under `04-notebooks/explore_data.ipynb`.

To upload this notebook:
* Navigate to BigQuery Studio, Notebooks
* Click on the 3 dots next to "Notebooks" to expand contextual menu, and select "Upload to Notebooks"
* Select URL option and use URL of the [notebook](../src/scripts/04-notebooks/explore_data.ipynb) in this Github repository. Alternatively you can clone the repo in your local environment and make any modifications.

Once uploaded, follow the step-by-step-instructions in the notebook.
* Connect the notebook to a Runtime. The first time, a default runtime is created; select the existing vpc network and subnet previously created.
* Fill in the notebook arguments in the first cell with the values from previous executions (project and location)
* Execute all the cells and check the results.

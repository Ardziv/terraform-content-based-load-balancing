# Content Based Load Balancing in Google Cloud

This provides a template for running an HTTP load balancer that distributes traffic to different instances based on the
path in the request URL. It is based on the tutorial at [https://cloud.google.com/compute/docs/load-balancing/http/content-based-example](https://cloud.google.com/compute/docs/load-balancing/http/content-based-example).

To start, [download your credentials from Google Cloud Console](https://www.terraform.io/docs/providers/google/#credentials); suggested path for downloaded file is `~/.gcloud/Terraform.json`.

Optionally update `variables.tf` to specify a default value for the `project_id` variable, and check other variables.

After you run `terraform apply` on this configuration, it will
automatically output the public IP address of the load balancer.
After your instance registers, the LB should respond with the following at its root: (using a service compute instance)

```html
<h1>www</h1>
```

And the following at the /video/ url: (using a service compute instance)
```html
<h1>www-video</h1>
```
And the following at the /static/ url: (using a backend bucket)
```html
<h1>WELCOME TO STATIC WEBSITE<h1>
```

To run, configure your Google Cloud provider as described in

https://www.terraform.io/docs/providers/google/index.html

Run with a command like this:

```
terraform apply \
	-var="region=asia-east2" \
	-var="region_zone=asia-east2-a" \
	-var="project_id=my-project-id-123" \
	-var="credentials_file_path=~/.gcloud/Terraform.json" \
```

Or save all your variable into a file `my-project-id-123.auto.tfvars` and call it like this:

```
terraform apply -auto-approve
```

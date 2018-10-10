# yace—yet another comment engine

> A simple, privacy-focussed and easy-to-deploy engine to build custom comment solutions.

![Accessing the comments from a blog post via the yace API using curl](https://cdn.baltpeter.io/img/yace-get.png)

yace aims to provide a comment engine that can be easily deployed to [AWS](https://aws.amazon.com/) (specifically [DynamoDB](https://aws.amazon.com/dynamodb/), [Lambda](https://aws.amazon.com/api-gateway/) and [API Gateway](https://aws.amazon.com/api-gateway/)) using [Terraform](https://www.terraform.io/). It is simple both in terms of the code that powers it and the APIs it provides.  
It can easily be integrated into existing websites and is ideal for static websites, making almost no assumptions about the structure of the website. The frontend can be entirely customized as it only provides a simple API for submitting and retrieving comments.

In addition, yace sets the focus on privacy, collecting no unnecessary data about the user. What matters is the comment itself—not the metadata around it. yace doesn't collect email and IP addresses and doesn't authenticate the user at all. By default, it doesn't even require the author's name to be specified, although the frontend implementation can of course work around that.

To combat spam and malicious content, all comments have to be approved before being available through the API. For every comment that is submitted, the administrators receive an email with a link to approve it.

## Installation

yace is provided as a Terraform module. To prepare the Lambda functions, it needs [Node.js](https://nodejs.org) and [npm](https://www.npmjs.com/) to be installed on the system.

To use it, simply include the module in your Terraform infrastructure definition. For more information, please refer to the [Terraform documentation on modules](https://www.terraform.io/docs/modules/usage.html).

Below is a minimal configuration example. See [below](#configuration) for a full reference of all available options.

```hcl
module "yace_comments" {
  source = "github.com/baltpeter/yace"
  service_url = ""
  token_sender = "comments@your-domain.tld"
  token_recipients = "admin@your-domain.tld, moderator@your-domain.tld"
  smtp_host = "mail.your-domain.tld"
  smtp_user = "johnny"
  smtp_password = "hunter2"
}
```

You can access the default API Gateway invocation URL using the `base_url` output of the module.

## API

As mentioned earlier, yace has no concept of what the comments it manages are for. In theory, it will work just as well for things other than websites. To match comments to the content they are in response to, yace uses the `target` attribute. You can define that to be whatever you want, as long as the same piece of content always gets the `target` value. An obvious solution would be the URL path but there's no reason not to use something else (like a filename, a unique ID or the hash of some unique property).  
Do note however, that all `target` values have to be URL-safe and both leading and trailing slashes and whitespace will be cut off.

### Submitting comments

Comments can be `PUT` to the root URL of your yace instance. The API expects a JSON payload like the following with at least the `message` and `target` properties set. If no `author` is specified, it will default to `Anonymous`.

You can also attach an object containing arbitrary keys and values that will be returned when the comment is accessed, via the `additional` property. The use of that parameter is discouraged though as yace aims to simple and privacy-focussed.

```json
{
	"author": "Benni",
	"target": "post/my-blog-post",
	"message": "Thank you. What a great blog post!\nI particularly like how you explain the importance of the topic in the beginning.",
	"additional": {
		"rating": 5
	}
}
```

When the comment was submitted successfully, the API will respond with an HTTP OK (`200`) response, otherwise it will respond with a JSON object with a `message` explaining the problem.

For successful comments, an email is sent to the email address specified in the `token_recipients` option. That email contains a link that can be used to accept the comment.

### Getting comments

To access the comments for a piece of content, simply send a `GET` request to `{service_url}/get/{target}`. The response will be a JSON array of all the comments (possibly none) relating to that `target` that have been accepted before.

```json
[
  {
    "message": "I disagree.",
    "added_at": "2018-10-10T01:01:33.048Z",
    "id": "7u4UygKynDCXR_RBZyqXJ",
    "additional": {},
    "author": "Anonymous"
  },
  {
    "message": "Thank you. What a great blog post!\nI particularly like how you explain the importance of the topic in the beginning.",
    "added_at": "2018-10-10T01:01:07.947Z",
    "id": "R0bFCe0PzQJ8pIIQ_j7n2",
    "additional": {
      "rating": 5
    },
    "author": "Benni"
  }
]
```

## Configuration

The following options can be configured.

| Option | Explanation | Default value | Required? |
| - | - | - | - |
| `name` | A name for your yace instance. This is primarily necessary if you want to run multiple instances alongside one another. | `yace-comments` | no |
| `enable_auto_backup` | Whether to automatically create backups of your data. Note that this will incur additional charges. | `false` | no |
| `service_url` | The URL to run the service at, necessary for token URLs. No trailing slash. Uses the default API Gateway invoke URL if left empty. |  | yes |
| `token_sender` | The email address to list as the sender of the token emails. |  | yes |
| `token_recipients` | A comma-separated list of recipients for the token emails. |  | yes |
| `smtp_host` | The SMTP host to use to deliver token emails for new comments. |  | yes |
| `smtp_port` | The SMTP port to use to deliver token emails for new comments. | `465` | no |
| `smtp_secure` | Whether to connect securely to the SMTP host to use to deliver token emails for new comments. From the nodemail docs: 'if true, the connection will use TLS when connecting to server. If false, TLS is used if server supports the STARTTLS extension. In most cases set this value to true if you are connecting to port 465. For port 587 or 25 keep it false'. | `true` | no |
| `smtp_user` | The SMTP user to use to deliver token emails for new comments. |  | yes |
| `smtp_password` | The SMTP user's password to use to deliver token emails for new comments. |  | yes |

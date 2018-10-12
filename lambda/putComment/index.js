'use strict';

const AWS = require('aws-sdk'),
	nanoid = require('nanoid'),
	documentClient = new AWS.DynamoDB.DocumentClient(),
	nodemailer = require('nodemailer');

let fail = function(err) {
	return addCors({
		statusCode: 500,
		body: JSON.stringify({ message: 'Error while storing the comment.' })
	});
};

exports.putComment = async function(event, context) {
	let body;
	try {
		body = JSON.parse(event.body);
	} catch (e) {
		return addCors({
			statusCode: 400,
			body: JSON.stringify({ message: 'Malformed request body.' })
		});
	}
	if (!body.message || !body.target)
		return addCors({
			statusCode: 400,
			body: JSON.stringify({ message: 'Missing required request data: message or target.' })
		});
	if (!body.author) body.author = 'Anonymous';

	let service_url =
		process.env.SERVICE_URL == ''
			? event.headers['X-Forwarded-Proto'] + '://' + event.headers.Host + '/' + event.requestContext.stage
			: process.env.SERVICE_URL;

	let comment = {
		Item: {
			id: nanoid(),
			author: stripTags(body.author),
			message: stripTags(body.message),
			target: body.target.replace(/[^a-zA-Z0-9/_-]/, '').replace(/^\s*\/*\s*|\s*\/*\s*$/gm, ''),
			additional: body.additional instanceof Object ? body.additional : {},
			accept_token: nanoid(),
			is_accepted: false,
			added_at: new Date().toISOString()
		},
		TableName: process.env.TABLE
	};

	return await documentClient
		.put(comment)
		.promise()
		.then(async function(data) {
			return sendTokenMail(comment.Item, service_url)
				.then(function(info) {
					return addCors({
						statusCode: 200,
						body: JSON.stringify({
							message:
								'Successfully added comment. It will need to be accepted by an administrator before it is published.'
						})
					});
				})
				.catch(fail);
		})
		.catch(fail);
};

async function sendTokenMail(comment, service_url) {
	let transporter = nodemailer.createTransport({
		host: process.env.SMTP_HOST,
		port: process.env.SMTP_PORT,
		secure: process.env.SMTP_SECURE == 'true',
		auth: {
			user: process.env.SMTP_USER,
			pass: process.env.SMTP_PASSWORD
		}
	});
	let mailOptions = {
		from: process.env.TOKEN_SENDER,
		to: process.env.TOKEN_RECIPIENTS,
		subject: 'New comment received for yace instance "' + process.env.INSTANCE_NAME + '"',
		text: `
A new comment has been submitted.

ID: "${comment.id}"
Author: "${comment.author}"
Target post: "${comment.target}"
Additional data: "${JSON.stringify(comment.additional)}"

Comment:
"${comment.message}"

Use the following link to accept the comment:
${service_url}/token/${comment.id}/${comment.accept_token}

If you don't want to accept the comment, you don't need to do anything.
		`
	};

	return transporter.sendMail(mailOptions);
}

function stripTags(str) {
	return str.replace(/<[^>]+>/gi, '');
}

function addCors(response) {
	response.headers = {
		'Access-Control-Allow-Origin': process.env.CORS_ALLOWED_ORIGIN
	};
	return response;
}

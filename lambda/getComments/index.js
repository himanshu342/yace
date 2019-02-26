'use strict';

const AWS = require('aws-sdk'),
	documentClient = new AWS.DynamoDB.DocumentClient();

exports.getComments = async function(event, context) {
	let target = event.pathParameters.proxy;

	return await documentClient
		.scan({
			TableName: process.env.TABLE,
			ExpressionAttributeValues: {
				':target': target,
				':accepted': true
			},
			FilterExpression: 'target = :target AND is_accepted = :accepted',

			ProjectionExpression: 'id, author, message, additional, added_at'
		})
		.promise()
		.then(function(data) {
			switch (event.resource) {
				case '/get/{proxy+}':
					return addCors({
						statusCode: 200,
						body: JSON.stringify(data.Items)
					});
					break;
				case '/feed/{proxy+}':
					return addCors({
						statusCode: 200,
						body: atomFeedForItems(data.Items, target),
						headers: {
							'Content-Type': 'application/atom+xml'
						}
					});
					break;
				default:
					return addCors({
						statusCode: 400,
						body: JSON.stringify({ message: 'Unsupported action.' })
					});
					break;
			}
		})
		.catch(function(err) {
			return addCors({
				statusCode: 500,
				body: JSON.stringify({ message: 'Fetching the comments failed.' })
			});
		});
};

function atomFeedForItems(items, target) {
	let entries = '';
	let feed_updated = '';

	// Excerpt regex taken from https://stackoverflow.com/a/5454297
	items.forEach(function(item) {
		entries += `	<entry>
		<title>${item.message.replace(/\s+/g, ' ').replace(/^(.{50}[^\s]*).*/, '$1')}</title>
		<id>yace:${process.env.INSTANCE_NAME}:${target}:comment:${item.id}</id>
		<updated>${item.added_at}</updated>
		<author><name>${item.author}</name></author>
		<content type="text">${item.message}</content>
	</entry>
`;

		if (item.added_at > feed_updated) feed_updated = item.added_at;
	});

	return `<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
	<title>${target}</title>
	<updated>${feed_updated}</updated>
	<id>yace:${process.env.INSTANCE_NAME}:${target}:comments</id>
	<generator uri="https://github.com/baltpeter/yace">yace</generator>

${entries}
</feed>
`;
}

function addCors(response) {
	response.headers = Object.assign({}, response.headers, {
		'Access-Control-Allow-Origin': process.env.CORS_ALLOWED_ORIGIN
	});
	return response;
}

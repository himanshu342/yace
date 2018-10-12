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
			return addCors({
				statusCode: 200,
				body: JSON.stringify(data.Items)
			});
		})
		.catch(function(err) {
			return addCors({
				statusCode: 500,
				body: JSON.stringify({ message: 'Fetching the comments failed.' })
			});
		});
};

function addCors(response) {
	response.headers = {
		'Access-Control-Allow-Origin': process.env.CORS_ALLOWED_ORIGIN
	};
	return response;
}

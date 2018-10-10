'use strict';

const AWS = require('aws-sdk'),
	documentClient = new AWS.DynamoDB.DocumentClient();

exports.acceptComment = async function(event, context) {
	let id = event.pathParameters.id;
	let token = event.pathParameters.token;

	return await documentClient
		.update({
			TableName: process.env.TABLE,
			Key: { id: id },
			UpdateExpression: 'set is_accepted = :true',
			ConditionExpression: 'attribute_exists(id) and is_accepted = :false and accept_token = :token',
			ExpressionAttributeValues: {
				':true': true,
				':false': false,
				':token': token
			}
		})
		.promise()
		.then(function(data) {
			return {
				statusCode: 200,
				body: JSON.stringify({ message: 'Successfully accepted comment.' })
			};
		})
		.catch(function(err) {
			return {
				statusCode: 500,
				body: JSON.stringify({
					message:
						'Accepting the comment failed. Is the token incorrect or has the comment been accepted already?'
				})
			};
		});
};

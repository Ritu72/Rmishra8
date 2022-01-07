// Install these packages via npm: npm install express aws-sdk multer multer-s3
var express = require('express'),
    aws = require('aws-sdk'),
    bodyParser = require('body-parser'),
    multer = require('multer'),
    multerS3 = require('multer-s3');

// needed to include to generate UUIDs
// https://www.npmjs.com/package/uuid
// below is the code to generate the random
const { v4: uuidv4 } = require('uuid');

aws.config.update({
    region: 'us-east-2'
});

// initialize an s3 connection object
var app = express(),
    s3 = new aws.S3();

// configure S3 parameters to send to the connection object
app.use(bodyParser.json());

//var name = '';
//var name = '';
// added the S3 bucket
/*s3.listBuckets(function(err, data) {
    if (err) console.log(err, err.stack); // an error occurred
    else     console.log(data.Buckets);           // successful response
    for (let i=0;i<data.Buckets.length;i++){
        if(data.Buckets[i]['Name'].includes('mp2-')){
          name = data.Buckets[i]['Name'];  
        }
    }*/
var upload = multer({
    storage: multerS3({
        s3: s3,
        bucket: 'mp2-rm-s3-bucket',
        key: function (req, file, cb) {
            cb(null, file.originalname);
            }
    })
});

// NodeJS needed to render the index file
app.get('/', function (req, res) {
    res.sendFile(__dirname + '/index.html');
});


// Code Needed to post the form when the Submit button is hit
app.post('/upload', upload.array('uploadFile',1), function (req, res, next) {
// https://www.npmjs.com/package/multer
// This retrieves the name of the uploaded file
var fname = req.files[0].originalname;

// Now we can construct the S3 URL since we already know the structure of S3 URLS and our bucket
// For this sample I hardcoded my bucket, you can do this or retrieve it dynamically
var s3url = "https://mp2-rm-s3-bucket.s3.amazonaws.com/" + fname;

//var s3url = "https://" + name + ".s3.amazonaws.com/" + fname;
// Use this code to retrieve the value entered in the username field in the index.html
var username = req.body['name'];
//added 
// Use this code to retrieve the value entered in the email field in the index.html
var email = req.body['email'];
// Use this code to retrieve the value entered in the phone field in the index.html
var phone = req.body['phone'];
// generate a UUID for this action
var id = uuidv4();
var sns = new aws.SNS({apiVersion: '2010-03-31'});
var topicArn = '';
var listparams = {}; 
    sns.listTopics(listparams, function(err, data) {
    if (err) console.log(err, err.stack); // an error occurred
    topicArn=data.Topics[0].TopicArn;           // successful response
  
    var params1={
    Protocol: 'email', /* required */
    TopicArn: topicArn, /* required */
    Endpoint: email, //12243881477
    ReturnSubscriptionArn: true
    };

    console.log('get the aws topic')
    sns.subscribe(params1, function(eer, data) {
    if (eer) console.log(eer, eer.stack); 
    });

      var params2 = {
      Message: s3url, /* required */
      Subject: 'MP2 coming at you!',
      TopicArn: topicArn
      };
      console.log('get the aws topic');
      sns.publish(params2, function(err, data) {
      if (err) console.log(err, err.stack); // an error occurred
      else console.log(data);           // successful response
      });

});

console.log("Sent message")

// initialize an dynamodb connection object in app added

var dynamodb = new aws.DynamoDB();
var params ={
};
var dbName="";
dynamodb.listTables(params, function(err, data) {
  if (err) console.log(err, err.stack); // an error occurred
  else    
  {
    console.log(data,"in list ");           // successful response
    dbName=data.TableNames[0];
  }
});
console.log('after list');
console.log(dbName);

//INSERT STATEMENT to insert the values from the POST method
var params={
  Item: {
   "RecordNumber": { S: id },
   "CustomerName": { S: username},
   "Email": { S: email },
   "Phone": { S: phone },
   "Stats": { S: "0" },
   "S3URL":  { S: s3url }
  },
  TableName: dbName
};

console.log('before put');
console.log(dbName);

dynamodb.putItem(params,function(err,data){
   if (err) console.log(err,err.stack);// an error occurred
   else console.log(data);
});
console.log('after put',dbName);

var params={
        
      TableName: dbName
};

var myData=[];
var parse=aws.DynamoDB.Converter.output;

dynamodb.scan(params,function(err,data){
          if (err) console.log(err,err.stack);// an error occurred
          else {
             myData=data.Items;
          }});
console.log('after scsn',myData);

// https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#sendMessage-property
// Write output to the screen of the app test
        res.write(s3url + "\n");
        res.write(username + "\n")
        res.write(fname + "\n");
        res.write("File uploaded successfully to Amazon S3 Server!" + "\n");
      
        res.end();
});
app.listen(3300, function() {
    console.log('Amazon s3 file upload app listening on port 3300');
});
//});
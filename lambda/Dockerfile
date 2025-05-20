## Dockerfile for Lambda Container Image


# lambda/Dockerfile
FROM public.ecr.aws/lambda/python:3.9

# Install required tools
RUN yum install -y unzip curl

# Copy function code
COPY function.py ${LAMBDA_TASK_ROOT}
COPY requirements.txt /tmp/

# Install Python dependencies
RUN pip install -r /tmp/requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Set the CMD to your handler
CMD [ "function.lambda_handler" ]
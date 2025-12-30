
FROM public.ecr.aws/lambda/python:3.12
COPY requirement.txt ${LAMBDA_TASK_ROOT}


RUN pip install --upgrade pip && \
    pip install -r requirement.txt


COPY summery.py ${LAMBDA_TASK_ROOT}
ENV HOME=/tmp
CMD [ "summery.handler" ]
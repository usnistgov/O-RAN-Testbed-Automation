python3 -m pip install pandas scikit-learn numpy
python3 -m pip install tensorflow keras

python3 -m pip install --upgrade pandas
python3 -m pip install --upgrade scikit-learn
python3 -m pip install --upgrade numpy
python3 -m pip install --upgrade tensorflow
python3 -m pip install --upgrade keras

python3 -m pip install tensorflow
python3 -m pip install cuda-python


REM python3 -m pip install tensorflow[and-cuda]
REM python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU')); print('\n\nNum GPUs Available: ', len(tf.config.experimental.list_physical_devices('GPU')))"

pause
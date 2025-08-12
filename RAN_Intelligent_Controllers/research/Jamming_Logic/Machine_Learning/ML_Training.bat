set LSTM_PARAMS=-m lr,rr,rf,gb,lstm,knn ^
--lstm_epochs 1000 ^
--lstm_batch_size 256 ^
--lstm_units 50 ^
--lstm_activation tanh ^
--lstm_recurrent_activation sigmoid ^
--lstm_dropout 0 ^
--lstm_recurrent_dropout 0 ^
--lstm_unroll 0 ^
--lstm_use_bias 1
python ML_Training.py %LSTM_PARAMS% -n "none" -d 0 -r 0.8 -c 1

pause
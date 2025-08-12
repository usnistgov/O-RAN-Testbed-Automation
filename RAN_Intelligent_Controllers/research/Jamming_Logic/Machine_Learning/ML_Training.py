preprocess_label_default = 0 # TX Gain = 0 when NaN

import os
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.model_selection import train_test_split
from sklearn.neighbors import KNeighborsRegressor
from sklearn.preprocessing import MinMaxScaler, StandardScaler
from sklearn.svm import SVR
from keras.models import Sequential
from keras.layers import Dense, LSTM
from keras.optimizers import Adam
from keras.callbacks import Callback, EarlyStopping
import numpy as np
import argparse
import joblib # For saving models
import pandas as pd
import re
import sys
import time
import json

# Given a regular expression, list the files that match it, and ask for user input
def selectFile(regex, subdirs=False):
	files = []
	if subdirs:
		for (dirpath, dirnames, filenames) in os.walk('.'):
			for file in filenames:
				path = os.path.join(dirpath, file)
				if path[:2] == '.\\':
					path = path[2:]
				if bool(re.match(regex, path)):
					files.append(path)
	else:
		for file in os.listdir(os.curdir):
			if os.path.isfile(file) and bool(re.match(regex, file)):
				files.append(file)

	print()
	if len(files) == 0:
		print(f'No files were found that match', regex)
		print()
		return ''

	print('List of files:')
	for i, file in enumerate(files):
		print(f'	File {i + 1}	-	{file}')
	print()

	selection = None
	while selection is None:
		try:
			i = int(input(f'Please select a file (1 to {len(files)}): '))
		except KeyboardInterrupt:
			sys.exit()
		except:
			pass
		if i > 0 and i <= len(files):
			selection = files[i - 1]
	print()
	return selection

'''
	parser = argparse.ArgumentParser(description='Train models on a dataset.')
	parser.add_argument('-f', '--file', help='Specify the file path of the CSV.', type=str)
	parser.add_argument('-n', '--normalization', help='Specify the normalization method (\'none\', \'minmax\', \'zscore\').', type=str, default='none')
	parser.add_argument('-d', '--discretize', help='Specify whether to use discretization (1/0).', type=str, default='0')
	parser.add_argument('-r', '--ratio', help='Specify the ratio of the data to use for training.', type=float, default=0.8)
	parser.add_argument('-c', '--chronological', help='Specify whether to split the data chronologically, 1, or randomly, 0, (1/0).', type=str, default='1')
	parser.add_argument('-m', '--models', help='Specify the models to use separated by commas (all,lr,rr,rf,gb,lstm,knn,svr,dnn).', type=str, default='all')
	parser.add_argument('--validation_split', help='Validation split for training the models.', type=float, default=0.2)
	parser.add_argument('--dnn_neurons', help='Number of neurons in each hidden layer of the DNN.', type=int, default=64)
	parser.add_argument('--dnn_activation', help='Activation function for the DNN (relu, sigmoid, tanh, softmax).', type=str, default='relu')
	parser.add_argument('--dnn_epochs', help='Number of epochs for the DNN.', type=int, default=1000)
	parser.add_argument('--dnn_batch_size', help='Batch size for the DNN.', type=int, default=64)
	parser.add_argument('--dnn_hidden_layers', help='Number of hidden layers for the deep neural network.', type=int, default=1)
	parser.add_argument('--lstm_epochs', help='Number of epochs for the LSTM.', type=int, default=1000)
	parser.add_argument('--lstm_batch_size', help='Batch size for the LSTM.', type=int, default=64)
	parser.add_argument('--lstm_units', help='Number of units in the LSTM layer.', type=int, default=50)
	parser.add_argument('--lstm_activation', help='Activation function for the LSTM (relu, sigmoid, tanh, softmax).', type=str, default='tanh')
	parser.add_argument('--lstm_recurrent_activation', help='Recurrent activation function for the LSTM (relu, sigmoid, tanh, softmax).', type=str, default='sigmoid')
	parser.add_argument('--lstm_dropout', help='Dropout rate for the LSTM layer.', type=float, default=0.2)
	parser.add_argument('--lstm_recurrent_dropout', help='Recurrent dropout rate for the LSTM layer.', type=float, default=0)
	parser.add_argument('--lstm_unroll', help='If the LSTM should use unroll (0, 1)', type=int, default=0)
	parser.add_argument('--lstm_use_bias', help='If the LSTM should use bias (0, 1)', type=int, default=1)
	parser.add_argument('--non_generalizable', help='If the training algorithm can use all of the training data and all of the testing data, effectively cheating (0, 1)', type=int, default=0)
'''
def main(file_path=None, normalization='none', discretize='0', trainingSplitRatio=0.8, trainingSplitChronological='1', models='all', validation_split=0.2, dnn_neurons=64, dnn_activation='relu', dnn_epochs=1000, dnn_batch_size=32, dnn_hidden_layers=1, lstm_epochs=1000, lstm_batch_size=32, lstm_units=50, lstm_activation='tanh', lstm_recurrent_activation='sigmoid', lstm_dropout=0.2, lstm_recurrent_dropout=0, lstm_unroll=0, lstm_use_bias=1, non_generalizable=0):
	labelColumn = 2 # Jammer TX Gain
	dataBeginColumn = 3

	# Determine whether to use discretization based on the argument
	useDiscretization = False
	if discretize:
		useDiscretization = discretize.lower(
		) in ['1', 'true', 't', 'yes', 'y']
	else:
		# Ask the user if no discretization argument was provided
		useDiscretization = ['1', 'true', 't', 'yes', 'y'].count(
			input('Use discretization? (y/n): ').lower()) > 0
	
	trainingSplitChronological = trainingSplitChronological.lower() in ['1', 'true', 't', 'yes', 'y']

	# If file_path is not provided as an argument, use selectFile function
	if file_path is None:
		file_path = selectFile(r'.*\.csv')
		if not file_path:
			sys.exit('No file selected. Exiting.')

	fileNameN = ['none', 'minmax', 'zscore'].index(normalization)
	if fileNameN == -1: fileNameN = 0
	fileNameD = '1' if useDiscretization else '0'
	fileNameR = str(trainingSplitRatio)
	fileNameC = '1' if trainingSplitChronological else '0'
	modelPath = 'models_'
	if non_generalizable == 1:
		modelPath += 'ng_'
	modelPath += f'n{fileNameN}_d{fileNameD}_r{fileNameR}_c{fileNameC}_' + os.path.splitext(file_path)[0]
	if not os.path.exists(modelPath):
		os.makedirs(modelPath)

	results_file_path = os.path.join(modelPath, 'training_results.csv')

	# Load the dataset
	df = pd.read_csv(file_path)

	# Split data into features and labels
	X = df.iloc[:, dataBeginColumn:]
	y = df.iloc[:, labelColumn]

	# Optional label preprocessing
	if preprocess_label_default is not None:
		y = pd.to_numeric(y, errors='coerce')
		y.fillna(preprocess_label_default, inplace=True)

	# Discretization
	if useDiscretization:
		y = y.round().astype(int)

	# Ensure features are numeric and handle NaNs
	X = X.apply(pd.to_numeric, errors='coerce')
	X.fillna(X.mean(), inplace=True)
	X.fillna(0, inplace=True)	# final fallback

	# Normalization
	if normalization.lower() == 'minmax':
		scaler = MinMaxScaler()
		X = scaler.fit_transform(X)
		joblib.dump(scaler, os.path.join(modelPath, 'minmax_scaler.pkl'))
	elif normalization.lower() == 'zscore':
		scaler = StandardScaler()
		X = scaler.fit_transform(X)
		joblib.dump(scaler, os.path.join(modelPath, 'zscore_scaler.pkl'))
	else:
		pass


	if non_generalizable == 1:
		# For testing purposes only - train and test on the full dataset for non-generalizable evaluation, which is used to test the model's ability to predict the same data it was trained on
		print('Training and testing on the full dataset for non-generalizable evaluation.')
		X_train, X_test = X.copy(), X.copy()
		y_train, y_test = y.copy(), y.copy()
	else:
		# Split data into training and testing sets
		if trainingSplitChronological:
			train_size = int(len(X) * trainingSplitRatio)
			X_train, X_test = X[:train_size], X[train_size:]
			y_train, y_test = y[:train_size], y[train_size:]
		else:
			X_train, X_test, y_train, y_test = train_test_split(
				X, y, test_size=(1 - trainingSplitRatio), shuffle=False)
		

	# Early Stopping for DNN
	early_stopping_dnn = EarlyStopping(
		monitor='val_loss', # Monitor validation loss
		patience=20, # Number of epochs with no improvement after which training will be stopped
		restore_best_weights=True, # Restore model weights from the epoch with the best value of the monitored quantity
	)

	# Early Stopping for LSTM
	early_stopping_lstm = EarlyStopping(
		monitor='val_loss',
		patience=20,
		restore_best_weights=True,
	)

	class LoggerLSTM(Callback):
		def on_train_begin(self, logs={}):
			self.train_mse = []
			self.val_mse = []

		def on_epoch_end(self, epoch, logs={}):
			self.train_mse.append(logs.get('loss'))
			self.val_mse.append(logs.get('val_loss'))

	# Models
	model_args = models.split(',')
	models = {}
	if 'all' in model_args or 'lr' in model_args:
		models['LinearRegression'] = LinearRegression()
	if 'all' in model_args or 'rr' in model_args:
		models['RidgeRegression'] = Ridge()
	if 'all' in model_args or 'rf' in model_args:
		models['RandomForest'] = RandomForestRegressor(random_state=42)
	if 'all' in model_args or 'gb' in model_args:
		models['GradientBoosting'] = GradientBoostingRegressor(random_state=42)
	if 'all' in model_args or 'lstm' in model_args:
		models['LSTMModel'] = None # Placeholder, actual model will be defined later
	if 'all' in model_args or 'knn' in model_args:
		models['KNearestNeighbors'] = KNeighborsRegressor()
	if 'all' in model_args or 'svr' in model_args:
		models['SupportVectorRegression'] = SVR()
	if 'all' in model_args or 'dnn' in model_args:
		models['DeepNeuralNetwork'] = None

	# Initialize an empty list to hold evaluation results
	results_list = []

	# Train and save models
	for name, model in models.items():
		if X_train.shape[0] == 0:
			continue
		print(f'\n\n\n\n\nTraining {name} with {X_train.shape[0]} samples and {X_train.shape[1]} features...')
		start_time = time.time()

		# Train and save DNN model
		if name == 'DeepNeuralNetwork':
			print('Training DeepNeuralNetwork with', dnn_neurons, 'neurons, activation', dnn_activation, 'and', dnn_hidden_layers, 'hidden layers...')
			start_time = time.time()

			# Define the DNN architecture using provided arguments
			layers = []
			layers.append(Dense(dnn_neurons, activation=dnn_activation, input_shape=(X_train.shape[1],)))
			# Add hidden layers
			for i in range(dnn_hidden_layers):
				layers.append(Dense(dnn_neurons, activation=dnn_activation))
			layers.append(Dense(1))
			model = Sequential(layers)
			model.compile(optimizer=Adam(), loss='mean_squared_error')

			# Apply early stopping if non-generalizable == 0
			callbacks = [] if non_generalizable == 1 else [early_stopping_dnn]
			
			model.fit(
				X_train, y_train,
				epochs=dnn_epochs,
				batch_size=dnn_batch_size,
				validation_split=validation_split,
				callbacks=callbacks,
			)

			# Adjust the model filename to include DNN parameters
			model_filename = os.path.join(modelPath, f'DNN_n{dnn_neurons}_{dnn_activation}_e{dnn_epochs}_b{dnn_batch_size}_h{dnn_hidden_layers}_model.keras')
			model.save(model_filename)

			end_time = time.time()
			training_time = end_time - start_time
			model_size = os.path.getsize(model_filename)
			results_list.append({
				'Model': 'DeepNeuralNetwork', 
				'Training Time (s)': training_time, 
				'Model Size (Bytes)': model_size,
				'Number of Features': X_train.shape[1], 
				'Number of Training Samples': X_train.shape[0],
				'Other Logs': ''
			})
			print('DeepNeuralNetwork model saved.')
		
		# Train and save LSTM model
		elif name == 'LSTMModel':
			print('Training LSTMModel with LSTM units:', lstm_units, 'and dropout:', lstm_dropout, 'and recurrent dropout:', lstm_recurrent_dropout, '...')
			start_time = time.time()

			# Reshape input to be [samples, time steps, features]
			X_train_reshaped = np.reshape(X_train, (X_train.shape[0], 1, X_train.shape[1]))

			# Define the LSTM model with the updated parameters
			model = Sequential()
			model.add(LSTM(lstm_units, activation=lstm_activation, recurrent_activation=lstm_recurrent_activation, dropout=lstm_dropout, recurrent_dropout=lstm_recurrent_dropout, input_shape=(X_train_reshaped.shape[1], X_train_reshaped.shape[2]), unroll=bool(lstm_unroll), use_bias=bool(lstm_use_bias)))
			model.add(Dense(1))
			model.compile(optimizer='adam', loss='mean_squared_error')

			logger_lstm = LoggerLSTM()

			# Apply early stopping if non-generalizable == 0
			callbacks = [] if non_generalizable == 1 else [early_stopping_lstm]
			callbacks.append(logger_lstm)

			# Fit the model
			model.fit(
				X_train_reshaped, y_train,
				epochs=lstm_epochs,
				batch_size=lstm_batch_size,
				validation_split=validation_split,
				callbacks=callbacks,
			)

			# Save the model
			model_filename = os.path.join(modelPath, f'LSTM_e{lstm_epochs}_b{lstm_batch_size}_u{lstm_units}_a{lstm_activation}_ra{lstm_recurrent_activation}_d{lstm_dropout}_rd{lstm_recurrent_dropout}_u{lstm_unroll}_b{lstm_use_bias}_model.keras')
			model.save(model_filename)

			# Log training time and model size
			end_time = time.time()

			# Create a list of dictionaries for each epoch
			logger_lstm_data = [
				{'e': epoch + 1, 'train_mse': train_mse, 'val_mse': val_mse}
				for epoch, (train_mse, val_mse) in enumerate(zip(logger_lstm.train_mse, logger_lstm.val_mse))
			]
			mse_json = json.dumps(logger_lstm_data).replace('"', "'")
			mse_json_for_csv = f'"{mse_json}"'

			training_time = end_time - start_time
			model_size = os.path.getsize(model_filename)
			results_list.append({
				'Model': 'LSTMModel', 
				'Training Time (s)': training_time, 
				'Model Size (Bytes)': model_size,
				'Number of Features': X_train_reshaped.shape[2], 
				'Number of Training Samples': X_train_reshaped.shape[0],
				'Other Logs': mse_json_for_csv
			})
			print('LSTMModel saved.')

		else:
			model.fit(X_train, y_train)
			model_filename = os.path.join(modelPath, f'{name}_model.pkl')
			joblib.dump(model, model_filename)

			end_time = time.time()
			training_time = end_time - start_time
			model_size = os.path.getsize(model_filename)
			results_list.append({
				'Model': name, 
				'Training Time (s)': training_time, 
				'Model Size (Bytes)': model_size,
				'Number of Features': X_train.shape[1], 
				'Number of Training Samples': X_train.shape[0],
				'Other Logs': ''
			})
			print(f'{name} model saved.')

	# Create a DataFrame from the list of results
	results_df = pd.DataFrame(results_list)

	# Save the results to a CSV file
	results_df.to_csv(results_file_path, index=False)

	# Convert X_test and y_test back to DataFrames before saving
	X_test_df = pd.DataFrame(X_test, columns=df.columns[dataBeginColumn:])
	y_test_df = pd.DataFrame(y_test, columns=[df.columns[labelColumn]])

	# Save test set
	X_test_df.to_csv(os.path.join(modelPath, 'X_test.csv'), index=False)
	y_test_df.to_csv(os.path.join(modelPath, 'y_test.csv'), index=False)


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='Train models on a dataset.')
	parser.add_argument('-f', '--file', help='Specify the file path of the CSV.', type=str)
	parser.add_argument('-n', '--normalization', help='Specify the normalization method (\'none\', \'minmax\', \'zscore\').', type=str, default='none')
	parser.add_argument('-d', '--discretize', help='Specify whether to use discretization (1/0).', type=str, default='0')
	parser.add_argument('-r', '--ratio', help='Specify the ratio of the data to use for training.', type=float, default=0.8)
	parser.add_argument('-c', '--chronological', help='Specify whether to split the data chronologically, 1, or randomly, 0, (1/0).', type=str, default='1')
	parser.add_argument('-m', '--models', help='Specify the models to use separated by commas (all,lr,rr,rf,gb,lstm,knn,svr,dnn).', type=str, default='all')
	parser.add_argument('--validation_split', help='Validation split for training the models.', type=float, default=0.2)
	parser.add_argument('--dnn_neurons', help='Number of neurons in each hidden layer of the DNN.', type=int, default=64)
	parser.add_argument('--dnn_activation', help='Activation function for the DNN (relu, sigmoid, tanh, softmax).', type=str, default='relu')
	parser.add_argument('--dnn_epochs', help='Number of epochs for the DNN.', type=int, default=1000)
	parser.add_argument('--dnn_batch_size', help='Batch size for the DNN.', type=int, default=64)
	parser.add_argument('--dnn_hidden_layers', help='Number of hidden layers for the deep neural network.', type=int, default=1)
	parser.add_argument('--lstm_epochs', help='Number of epochs for the LSTM.', type=int, default=1000)
	parser.add_argument('--lstm_batch_size', help='Batch size for the LSTM.', type=int, default=64)
	parser.add_argument('--lstm_units', help='Number of units in the LSTM layer.', type=int, default=50)
	parser.add_argument('--lstm_activation', help='Activation function for the LSTM (relu, sigmoid, tanh, softmax).', type=str, default='tanh')
	parser.add_argument('--lstm_recurrent_activation', help='Recurrent activation function for the LSTM (relu, sigmoid, tanh, softmax).', type=str, default='sigmoid')
	parser.add_argument('--lstm_dropout', help='Dropout rate for the LSTM layer.', type=float, default=0.2)
	parser.add_argument('--lstm_recurrent_dropout', help='Recurrent dropout rate for the LSTM layer.', type=float, default=0)
	parser.add_argument('--lstm_unroll', help='If the LSTM should use unroll (0, 1)', type=int, default=0)
	parser.add_argument('--lstm_use_bias', help='If the LSTM should use bias (0, 1)', type=int, default=1)
	parser.add_argument('--non_generalizable', help='If the training algorithm can use all of the training data and all of the testing data, effectively cheating (0, 1)', type=int, default=0)

	args = parser.parse_args()
	main(
		file_path=args.file,
		normalization=args.normalization,
		discretize=args.discretize,
		trainingSplitRatio=args.ratio,
		trainingSplitChronological=args.chronological,
		models=args.models,
		validation_split=args.validation_split,
		dnn_neurons=args.dnn_neurons,
		dnn_activation=args.dnn_activation,
		dnn_epochs=args.dnn_epochs,
		dnn_batch_size=args.dnn_batch_size,
		dnn_hidden_layers=args.dnn_hidden_layers,
		lstm_epochs=args.lstm_epochs,
		lstm_batch_size=args.lstm_batch_size,
		lstm_units=args.lstm_units,
		lstm_activation=args.lstm_activation,
		lstm_recurrent_activation=args.lstm_recurrent_activation,
		lstm_dropout=args.lstm_dropout,
		lstm_recurrent_dropout=args.lstm_recurrent_dropout,
		lstm_unroll=args.lstm_unroll,
		lstm_use_bias=args.lstm_use_bias,
		non_generalizable=args.non_generalizable
	)
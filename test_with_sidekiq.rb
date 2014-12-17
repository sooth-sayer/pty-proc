require 'hard_worker'

HardWorker.perform_async('git@bitbucket.org:hexlet-exercises/java_classes_exercise.git', 'PtyRunner')

HardWorker.perform_async('git@bitbucket.org:hexlet-exercises/javascript_strings_exercise.git', 'PtyRunner')

HardWorker.perform_async('git@bitbucket.org:hexlet-exercises/javascript_arguments_exercise.git', 'PtyRunner')

create_predict_fun <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  UseMethod("create_predict_fun")
}

create_predict_fun.WrappedModel <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  if (!requireNamespace("mlr")) {
    "Please install the mlr package."
  }
  if (task == "classification") {
    function(newdata) {
      pred <- predict(model, newdata = newdata)
      if (model$learner$predict.type == "response") {
        pred <- mlr::getPredictionResponse(pred)
        factor_to_dataframe(pred)
      } else {
        mlr::getPredictionProbabilities(pred, cl = model$task.desc$class.levels)
      }
    }
  } else if (task == "regression") {
    function(newdata) {
      pred <- predict(model, newdata = newdata)
      data.frame(.prediction = mlr::getPredictionResponse(pred))
    }
  } else {
    stop(sprintf("Task type '%s' not supported", task))
  }
}


create_predict_fun.Learner <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  if (!requireNamespace("mlr3")) {
    "Please install the mlr3 package."
  }
  if (task == "classification") {
    function(newdata) {
      if (model$predict_type == "response") {
        #pred <- predict(model, newdata = newdata)
        pred = model$predict_newdata(newdata, task_benchmark)[[model$predict_type]]
        factor_to_dataframe(pred)
      } else {
        #data.frame(predict(model, newdata = newdata, predict_type = "prob"), check.names = FALSE)
        pred = data.frame(model$predict_newdata(newdata, task_benchmark)[[model$predict_type]], check.names = FALSE)
      }
    }
  } else if (task == "regression") {
    function(newdata) {
      #data.frame(predict(model, newdata = newdata))
      data.table(model$predict_newdata(newdata, task_benchmark)) #--> still need to test this
    }
  } else {
    stop(sprintf("Task type '%s' not supported", task))
  }
}


create_predict_fun.train <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  if (task == "classification") {
    function(newdata) {
      if (is.null(type)) {
        pred <- predict(model, newdata = newdata)
      } else {
        pred <- predict(model, newdata = newdata, type = type)
      }
      if (is_label(pred)) {
        pred <- factor_to_dataframe(pred)
      }
      pred
    }
  } else if (task == "regression") {
    function(newdata) {
      if (is.null(type)) {
        prediction <- predict(model, newdata = newdata)
      } else {
        prediction <- predict(model, newdata = newdata, type = type)
      }
      data.frame(.prediction = prediction, check.names = FALSE)
    }
  } else {
    stop(sprintf("task of type %s not allowed.", task))
  }
}



create_predict_fun.NULL <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  function(newdata) {
    pred <- predict.fun(newdata = newdata)
    if (is_label(pred)) {
      factor_to_dataframe(pred)
    }
    data.frame(pred, check.names = FALSE)
  }
}

#' @importFrom stats model.matrix
create_predict_fun.default <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  if (is.null(predict.fun)) {
    if (is.null(type)) {
      predict.fun <- function(object, newdata) predict(object, newdata)
    } else {
      predict.fun <- function(object, newdata) predict(object, newdata, type = type)
    }
  }
  function(newdata) {
    pred <- do.call(predict.fun, list(model, newdata = newdata))
    if (is_label(pred)) {
      pred <- factor_to_dataframe(pred)
    }
    data.frame(pred, check.names = FALSE)
  }
}

create_predict_fun.keras.engine.training.Model <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  if (is.null(predict.fun)) {
    predict.fun <- function(object, newdata) predict(object, newdata)
  }
  function(newdata) {
    pred <- do.call(predict.fun, list(model, newdata = as.matrix(newdata)))
    data.frame(pred, check.names = FALSE)
  }
}

create_predict_fun.H2ORegressionModel <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  function(newdata) {
    newdata2 <- h2o::as.h2o(newdata)
    as.data.frame(h2o::h2o.predict(model, newdata = newdata2))
  }
}


create_predict_fun.H2OBinomialModel <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  function(newdata) {
    # TODO: Include predict.fun and type
    newdata2 <- h2o::as.h2o(newdata)
    as.data.frame(h2o::h2o.predict(model, newdata = newdata2))[, -1]
  }
}

create_predict_fun.H2OMultinomialModel <- function(model, task, predict.fun = NULL, type = NULL, task_benchmark = NULL) {
  function(newdata) {
    # TODO: Include predict.fun and type
    newdata2 <- h2o::as.h2o(newdata)
    # Removes first column with classification
    # Following columns contain the probabilities
    as.data.frame(h2o::h2o.predict(model, newdata = newdata2))[, -1]
  }
}



factor_to_dataframe <- function(fac) {
  check_vector(fac)
  res <- data.frame(model.matrix(~ fac - 1, data.frame(fac = fac), sep = ":"))
  colnames(res) <- substring(colnames(res), 4)
  res
}

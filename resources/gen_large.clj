#!/usr/bin/env/bb

(defn gen-phone-number [n] (apply str (repeatedly n #(rand-int 9))))

(defn gen-large [{:keys [nrows phone-num-size]}]
  (run! println (repeatedly nrows #(gen-phone-number phone-num-size))))

(gen-large {:nrows (Long/parseLong (first *command-line-args*)) 
            :phone-num-size (Long/parseLong (second *command-line-args*))})

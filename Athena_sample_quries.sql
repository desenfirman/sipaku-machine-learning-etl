CREATE EXTERNAL TABLE datasource (
   y              int,
   age            int,           
   job            string,           
   marital        string ,       
   education      string,     
   default        string,      
   housing        string,       
   loan           string,          
   contact        string,       
   month          string,         
   day_of_week    string,   
   duration       int,      
   campaign       int,      
   pdays          int ,         
   previous       int ,      
   poutcome       string,      
   emp_var_rate   double,  
   cons_price_idx double,
   cons_conf_idx  double, 
   euribor3m      double,     
   nr_employed    double 
)
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' ESCAPED BY '\\' LINES TERMINATED BY '\n' 
LOCATION 's3://<bucket name>/<your path>/';

 
--  Calculate correlation coeffient for some columns ---
SELECT corr( age, y) AS correlation_age_and_target, 
       corr( duration , y ) AS correlation_duration_and_target, 
       corr( campaign , y ) AS correlation_campaign_and_target,
       corr( contact , y ) AS correlation_contact_and_target
FROM ( SELECT age , duration , campaign , y , 
              CASE WHEN contact = 'telephone' THEN 1 ELSE 0 END AS contact 
       FROM datasource 
     ) datasource ;


-- Age Range distribution for people who subscribed new product ---
SELECT floor( age / 10 ) * 10 AS aga_group , count(age) AS age_group_count
FROM datasource 
WHERE y > 0
GROUP BY floor( age / 10 ) * 10
ORDER BY 2 desc 



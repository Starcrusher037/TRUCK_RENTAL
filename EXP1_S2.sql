VAR b_fecha_proceso VARCHAR2(10);
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE, 'YYYY-MM-DD');

DECLARE
    v_contador_registros NUMBER(3) := 0;
    v_total_empleados number(3) :=0; --contador de empleados 
    v_fecha_proceso DATE; --fecha de ejecucion del bloque
    v_nombre_completo VARCHAR2(100);
    v_pnombre empleado.pnombre_emp%TYPE;
    v_snombre empleado.snombre_emp%TYPE;
    v_p_ap empleado.appaterno_emp%TYPE;
    v_s_ap empleado.apmaterno_emp%TYPE;
    
    --VARIABLES PARA DATOS MODIFICADOS PARA COMPOSICION DE USUARIO
    v_pletra_est_civ VARCHAR2(1);  --primer letra en minuscula
    v_tpletras_nom VARCHAR2(3); --tres primeras letras del nombre
    v_largo_nom NUMBER(2); --largo nombre
    v_asterisco VARCHAR2(1) :='*';
    v_udig_sbase NUMBER(1); --ultimo digito sueldo base
    v_anios_trab NUMBER(2); --años trabajados en la empresa
    v_car_e_reg VARCHAR2(1) := 'X';
    v_nombre_usuario VARCHAR2(50);
    
    --VARIABLES PARA DATOS MODIFICADOS PARA CONTRASEÑA
    v_tdig_run NUMBER(1); --tercer digito del run
    v_nac_mas NUMBER(4); --año de nacimiento +2 
    v_tres_dig_m1 VARCHAR2(3); --tres ultimos digitos del sueldo -1
    v_letras_ap VARCHAR2(2); -- dos letras del apellido paterno.
    v_mes_anio_sis VARCHAR2(6); -- mes/año del sistema 
    v_contrasenia VARCHAR2(30);
    
    --INICIO DEL BLOQUE
BEGIN
    --TRUCADO DE TABLA PARA MULTIPLES EJECUCIONES.
    EXECUTE IMMEDIATE 'TRUNCATE TABLE usuario_clave';
    
    --BLOQUE DE ITERACION PARA OBTENER DATOS DEL EMPLEADO CON CURSOR IMPLICITO
    FOR r IN(
        SELECT
            ec.nombre_estado_civil, 
            e.pnombre_emp, 
            e.sueldo_base,  
            e.dvrun_emp,   
            e.fecha_contrato, 
            e.numrun_emp,
            e.fecha_nac,
            e.appaterno_emp, 
            e.id_emp, 
            e.snombre_emp,
            e.apmaterno_emp
        FROM empleado e
        INNER JOIN estado_civil ec ON e.id_estado_civil = ec.id_estado_civil
    )LOOP --****************************INICIO LOOP PARA PROCESAR DATOS ***************************************
        v_total_empleados := v_total_empleados+1;   
         

    ------------------------------------PROCESAMIENTO DE DATOS--------------------------------
    v_fecha_proceso := TO_DATE(:b_fecha_proceso,'YYYY-MM-DD'); --AQUI OBTENEMOS LA FECHA TIPO DATE
    v_pnombre := r.pnombre_emp;
    v_snombre := NVL(r.snombre_emp,' ');  --según estructura de tabla este campo puede ser nulo(CONTROL CON NVL)
    v_p_ap := r.appaterno_emp;
    v_s_ap := r.apmaterno_emp;
    v_nombre_completo := UPPER(v_pnombre ||' '|| v_snombre ||' '|| v_p_ap ||' '|| v_s_ap);
    
    
    --PREPARACION DE DATOS Y CREACION DE USUARIO(segun instructivo)..ver al final del script
    v_pletra_est_civ := LOWER(SUBSTR(r.nombre_estado_civil,1,1));  
    v_tpletras_nom := SUBSTR(v_pnombre,1,3); 
    v_largo_nom := LENGTH(TRIM(v_pnombre));
    v_udig_sbase := SUBSTR(TRIM(TO_CHAR(r.sueldo_base)),-1,1); 
    v_anios_trab := TRUNC((MONTHS_BETWEEN(v_fecha_proceso, r.fecha_contrato))/12);
    
    --asignacion de valor compuesto a usuario
    v_nombre_usuario := v_pletra_est_civ || v_tpletras_nom || v_largo_nom || v_asterisco || v_udig_sbase || 
        r.dvrun_emp || v_anios_trab;
    
    --agregacion de caracter 'X' si el empleado lleva menos de 10 años en la empresa. 
    IF v_anios_trab < 10 THEN v_nombre_usuario := CONCAT(v_nombre_usuario,v_car_e_reg);
    END IF;
    
    
    
    --CREACION DE CONTRASEÑA (segun instructivo)..ver al final del script
    v_tdig_run := SUBSTR(TRIM(TO_CHAR(r.numrun_emp)),3,1); 
    v_nac_mas := (EXTRACT(YEAR FROM r.fecha_nac)+2);
    v_tres_dig_m1 := SUBSTR(TRIM(TO_CHAR((r.sueldo_base-1))),-3,3);
    
    --obtencion de 2 letras del apellido dependiendo de su estado civil
    IF r.nombre_estado_civil = 'CASADO' OR r.nombre_estado_civil = 'ACUERDO DE UNION CIVIL' THEN
        v_letras_ap := LOWER(SUBSTR(v_p_ap,1,2));
    ELSIF r.nombre_estado_civil = 'DIVORCIADO' OR r.nombre_estado_civil = 'SOLTERO' THEN
         v_letras_ap := LOWER(SUBSTR(v_p_ap,1,1)) || LOWER(SUBSTR(v_p_ap,-1,1));
    ELSIF r.nombre_estado_civil = 'VIUDO' THEN
         v_letras_ap := LOWER(SUBSTR(v_p_ap,-3,2));
    ELSE v_letras_ap := LOWER(SUBSTR(v_p_ap,-2,2));     
    END IF;
       
    --obtencion de mes y año como tipo varchar
    v_mes_anio_sis := TO_CHAR(v_fecha_proceso,'MM') || TO_CHAR(v_fecha_proceso,'YYYY') ;
    
    --asignacion de valores a contraseña
    v_contrasenia := v_tdig_run || v_nac_mas || v_tres_dig_m1 ||  v_letras_ap || r.id_emp || v_mes_anio_sis;
    
    --INSERCION DE DATOS A TABLA "USUARIO_CLAVE"
    INSERT INTO usuario_clave
    VALUES(r.id_emp, r.numrun_emp, r.dvrun_emp, v_nombre_completo, v_nombre_usuario, v_contrasenia);
 
    --contador de filas insertadas 
    v_contador_registros := v_contador_registros + SQL%ROWCOUNT;
     END LOOP;
    --*************************************AQUÍ TERMINA EL LOOP*******************************************
     
     /*CHEQUEO DE COINCIDENCIA ENTRE CANTIDAD DE USUARIOS Y CANTIDAD DE FILAS INSERTADAS, 
     EN CASO DE COINCIDIR SE CONFIRMAN CAMBIOS SINO SE REALIZA ROLLBACK.
     EN AMBOS CASOS SE MUESTRA UN MENSAJE AL USUARIO*/

    IF v_contador_registros = v_total_empleados THEN DBMS_OUTPUT.put_line('USUARIOS Y CONTRASEÑAS CREADAS EXITOSAMENTE');
        COMMIT;
    ELSE DBMS_OUTPUT.put_line('SE A PRODUCIDO UNA INCONSISTENCIA EN LOS DATOS.');
        ROLLBACK;  
    END IF;
     
END;
/

--SELECT SIMPLE PARA VISUALIZACION DE USUARIOS ORDENADOS POR NUMERO DE ID
SELECT * 
FROM usuario_clave
ORDER BY 1;

--REGLAS PARA CREAR USUARIO Y CONTRASEÑA
 /* Nombre de usuario será la unión de:
    a) La primera letra de su estado civil en minúscula.
    b) Las tres primeras letras del primer nombre del empleado.
    c) El largo de su primer nombre.
    d) Un ASTERISCO.
    e) El último dígito de su sueldo base.
    f) El dígito verificador del run del empleado.
    g) Los años que lleva trabajando en la empresa.
    h) Si el empleado lleva menos de 10 años trabajando en TRUCK RENTAL, se agrega
    además una X.
    
    Clave del usuario será la unión de:
    a) El tercer dígito del run del empleado.
    b) El año de nacimiento del empleado aumentado en dos.
    c) Los tres últimos dígitos del sueldo base disminuido en uno.
    d) Dos letras de su apellido paterno, en minúscula, de acuerdo a lo siguiente:
    ? Si es casado o con acuerdo de unión civil, las dos primeras letras.
    ? Si es divorciado o soltero, la primera y última letra.
    ? Si es viudo, la antepenúltima y penúltima letra.
    ? Si es separado las dos últimas letras.
    e) La identificación del empleado.
    f) El mes y año de la base de datos (en formato numérico).
    */
    
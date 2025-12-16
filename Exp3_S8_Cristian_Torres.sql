/* ---- Script ejecutado por usuario ADMIN ---- */

-- Crear usuario PRY2205_USER1

CREATE USER PRY2205_USER1
IDENTIFIED BY OracleCloud123
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON DATA;

-- Rol para PRY2205_USER1

CREATE ROLE PRY2205_ROL_D;

-- Privilegios para PRY2205_USER1 a traves de rol

GRANT CREATE SESSION TO PRY2205_ROL_D;
GRANT CREATE TABLE TO PRY2205_ROL_D;
GRANT CREATE VIEW TO PRY2205_ROL_D;
GRANT CREATE SYNONYM TO PRY2205_ROL_D;
GRANT CREATE PUBLIC SYNONYM TO PRY2205_ROL_D;

-- Asignar rol a User1
GRANT PRY2205_ROL_D TO PRY2205_USER1;

-- Crear usuario PRY2205_USER2

CREATE USER PRY2205_USER2
IDENTIFIED BY OracleCloud123
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON DATA;

-- Rol para PRY2205_USER2

CREATE ROLE PRY2205_ROL_P;

-- Privilegios para PRY2205_USER2 a traves de rol

GRANT CREATE SESSION TO PRY2205_ROL_P;
GRANT CREATE SEQUENCE TO PRY2205_ROL_P;
GRANT CREATE TRIGGER TO PRY2205_ROL_P;
GRANT CREATE TABLE TO PRY2205_ROL_P;

-- Asignar rol a User2
GRANT PRY2205_ROL_P TO PRY2205_USER2;

-- Permisos de consulta para USER2 vía rol
GRANT SELECT ON PRY2205_USER1.libro TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.ejemplar TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.prestamo TO PRY2205_ROL_P;


/* ---- Script ejecutado por usuario PRY2205_USER1 ---- */

--SE EJECUTA EL SCRIPT CON LA CREACION Y LA INSERCION DE DATOS 

--Se crean los sinonimos publicos para el user2

CREATE PUBLIC SYNONYM sn_libro FOR libro;
CREATE PUBLIC SYNONYM sn_ejemplar FOR ejemplar;
CREATE PUBLIC SYNONYM sn_prestamo FOR prestamo;


/* ---- Script ejecutado por usuario PRY2205_USER2 ---- */
/* ---- Caso 2: Creación de Informe ---- */

--LIMPIEZA PREVIA
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE control_stock_libros PURGE';
EXCEPTION
    WHEN OTHERS THEN
       NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_control_stock';
EXCEPTION
     WHEN OTHERS THEN
       NULL;
END;
/

--CREACION DE SECUENCIA
CREATE SEQUENCE SEQ_CONTROL_STOCK START WITH 1 INCREMENT BY 1;

--CREACION DE TABLA 
CREATE TABLE control_stock_libros AS
SELECT
    seq_control_stock.NEXTVAL AS id_control,
    t.libro_id,
    t.nombre_libro,
    t.total_ejemplares,
    t.en_prestamo,
    t.disponibles,
    t.porcentaje_prestamo,
    t.stock_critico
FROM (
    SELECT
    l.libroid AS libro_id,
    l.nombre_libro AS nombre_libro,
    COUNT(DISTINCT e.ejemplarid) AS total_ejemplares,
    COUNT(
        DISTINCT CASE
            WHEN p.empleadoid IN (190, 180, 150)
            THEN e.ejemplarid
        END
    ) AS en_prestamo,
    COUNT(DISTINCT e.ejemplarid)
    -
    COUNT(
        DISTINCT CASE
            WHEN p.empleadoid IN (190, 180, 150)
            THEN e.ejemplarid
        END
    ) AS disponibles,

    ROUND(
        100
        * COUNT(
            DISTINCT CASE
                WHEN p.empleadoid IN (190, 180, 150)
                THEN e.ejemplarid
            END
        )
        / NULLIF(COUNT(DISTINCT e.ejemplarid), 0),
        0
    ) AS porcentaje_prestamo,

/*ESTA COLUMNA NO COINCIDE CON LA IMAGEN DE LA GUIA PERO SI CON EL ENUNCIADO
Si existen más de 2 ejemplares disponibles, se asigna el valor 'S' (suficiente stock); 
en caso contrario, se asigna 'N' (stock crítico).*/

    CASE
        WHEN
            (
                COUNT(DISTINCT e.ejemplarid)
                -
                COUNT(
                    DISTINCT CASE
                        WHEN p.empleadoid IN (190, 180, 150)
                        THEN e.ejemplarid
                    END
                )
            ) > 2
        THEN 'S'
        ELSE 'N'
    END AS stock_critico
    FROM sn_libro l
    JOIN sn_ejemplar e
        ON e.libroid = l.libroid
    LEFT JOIN sn_prestamo p
        ON p.libroid    = e.libroid
        AND p.ejemplarid = e.ejemplarid
        AND p.fecha_inicio >= TO_DATE(EXTRACT(YEAR FROM SYSDATE) - 2 || '0101', 'YYYYMMDD')
        AND p.fecha_inicio <  TO_DATE(EXTRACT(YEAR FROM SYSDATE) - 1 || '0101', 'YYYYMMDD')
    WHERE EXISTS (
        SELECT 1
        FROM sn_prestamo p2
        WHERE p2.libroid = l.libroid
            AND p2.empleadoid IN (190, 180, 150)
            AND p2.fecha_inicio >= TO_DATE(EXTRACT(YEAR FROM SYSDATE) - 2 || '0101', 'YYYYMMDD')
            AND p2.fecha_inicio <  TO_DATE(EXTRACT(YEAR FROM SYSDATE) - 1 || '0101', 'YYYYMMDD'))
    GROUP BY
        l.libroid,
        l.nombre_libro
    ORDER BY
        l.libroid) t;

--CONSULTA DE LA TABLA CONTROL_STOCK_LIBROS
SELECT * FROM CONTROL_STOCK_LIBROS
ORDER BY libro_id ASC;

/* ---- Script ejecutado por usuario PRY2205_USER1 ---- */

/* ---- Caso 3: Optimización de sentencias SQL ---- */

--Sinonimos privados para el caso 3

CREATE SYNONYM sn_alumno FOR alumno;
CREATE SYNONYM sn_carrera FOR carrera;
CREATE SYNONYM sn_rebaja_multa FOR rebaja_multa;

--Caso 3.1: Creación de Vista

CREATE OR REPLACE VIEW VW_DETALLE_MULTAS AS
SELECT 
    p.prestamoid AS id_prestamo,
    INITCAP(a.nombre || ' ' || a.apaterno) AS nombre_alumno,
    c.descripcion AS nombre_carrera,
    p.libroid AS id_libro,
    TO_CHAR(l.precio,  '$999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS valor_libro,
    p.fecha_termino,
    p.fecha_entrega,
    p.fecha_entrega - p.fecha_termino AS dias_atraso,
    TO_CHAR(
        ROUND(l.precio * 0.03 * (p.fecha_entrega - p.fecha_termino),0)
        , '$999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS valor_multa,
    NVL(rm.porc_rebaja_multa/100,0) AS porcentaje_rebaje_multa,
    TO_CHAR(
        ROUND(l.precio * 0.03 * (p.fecha_entrega - p.fecha_termino)*
        (1-NVL(rm.porc_rebaja_multa/100,0)),0)
        , '$999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS valor_rebajado
FROM sn_prestamo p
LEFT JOIN sn_alumno a
    ON p.alumnoid = a.alumnoid
LEFT JOIN sn_carrera c
    ON a.carreraid = c.carreraid
LEFT JOIN sn_libro l
    ON p.libroid = l.libroid
LEFT JOIN sn_rebaja_multa rm
    ON a.carreraid = rm.carreraid
WHERE p.fecha_entrega > p.fecha_termino
AND EXTRACT(YEAR FROM p.fecha_termino) =
    EXTRACT(YEAR FROM SYSDATE) - 2
ORDER BY p.fecha_entrega DESC;

--CONSULTA DE LA VISTA
SELECT * FROM VW_DETALLE_MULTAS;

--Caso 3.2: Creación de Índices

--Limpieza de indice
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRESTAMO_ANIO_TERMINO';
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

/*El plan de ejecución se ve un FULL sobre la tabla PRESTAMO
debido al uso de la función EXTRACT(YEAR FROM fecha_termino) en el WHERE.*/

CREATE INDEX IDX_PRESTAMO_ANIO_TERMINO
ON PRESTAMO (EXTRACT(YEAR FROM fecha_termino));

--CONSULTA DE LA VISTA CON EL INDICE CREADO
SELECT * FROM VW_DETALLE_MULTAS;
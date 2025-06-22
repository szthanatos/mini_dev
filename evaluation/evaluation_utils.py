import json
from pathlib import Path

import psycopg2
import pymysql
import sqlite3


def load_json_data(file_path):
    file = Path(file_path)
    if file.suffix == ".json":
        return load_json(file)
    elif file.suffix == ".jsonl":
        return load_jsonl(file)
    else:
        raise ValueError("Invalid file type")


def load_jsonl(file_path):
    data = []
    with open(file_path, "r") as file:
        for line in file:
            data.append(json.loads(line))
    return data


def load_json(dir):
    with open(dir, "r") as j:
        contents = json.loads(j.read())
    return contents


def parse_dsn(dsn: str) -> dict:
    db_type, domain_ = dsn.split("://")
    domain, db_name = domain_.split("/")
    user_pass, host_port = domain.split("@")
    user, password = user_pass.split(":")
    host, port = host_port.split(":")
    return {
        "db_type": db_type,
        "database": db_name,
        "user": user,
        "password": password,
        "host": host,
        "port": port,
    }


# psycopg2   2.9.9
def connect_postgresql(**kwargs):
    # Open database connection
    # Connect to the database
    # - *dbname*: the database name
    # - *database*: the database name (only as keyword argument)
    # - *user*: user name used to authenticate
    # - *password*: password used to authenticate
    # - *host*: database host address (defaults to UNIX socket if not provided)
    # - *port*: connection port number (defaults to 5432 if not provided)
    db = psycopg2.connect(**kwargs)
    return db


# PyMySQL  1.1.1
def connect_mysql(**kwargs):
    # Open database connection
    # Connect to the database
    # user = (None,)  # The first four arguments is based on DB-API 2.0 recommendation.
    # password = ("",)
    # host = (None,)
    # database = (None,)
    # port = (0,)
    db = pymysql.connect(**kwargs)
    return db


def connect_db(sql_dialect, db_path, dsn):
    if sql_dialect == "SQLite":
        conn = sqlite3.connect(db_path)
    elif sql_dialect == "MySQL":
        conn = connect_mysql(**dsn)
    elif sql_dialect == "PostgreSQL":
        conn = connect_postgresql(**dsn)
    else:
        raise ValueError("Unsupported SQL dialect")
    return conn


def execute_sql(predicted_sql, ground_truth, calculate_func, sql_dialect, db_path, dsn):
    conn = connect_db(sql_dialect, db_path, dsn)
    # Connect to the database
    cursor = conn.cursor()
    cursor.execute(predicted_sql)
    predicted_res = cursor.fetchall()
    cursor.execute(ground_truth)
    ground_truth_res = cursor.fetchall()
    conn.close()
    res = calculate_func(predicted_res, ground_truth_res)
    return res


def package_sqls(sql_path, db_root_path, mode="pred"):
    clean_sqls = []
    db_path_list = []
    if mode == "pred":
        # use chain of thought
        sql_data = json.load(
            open(
                sql_path,
                "r",
            )
        )
        for _, sql_str in sql_data.items():
            if isinstance(sql_str, str):
                try:
                    sql, db_name = sql_str.split("\t----- bird -----\t")
                except ValueError:
                    sql = sql_str.strip()
                    db_name = "financial"
            else:
                sql = " "
                db_name = "financial"
            clean_sqls.append(sql)

    elif mode == "gt":
        sqls = open(sql_path)
        sql_txt = sqls.readlines()
        for idx, sql_str in enumerate(sql_txt):
            sql, db_name = sql_str.strip().split("\t")
            clean_sqls.append(sql)
            db_path_list.append(db_root_path + db_name + "/" + db_name + ".sqlite")

    return clean_sqls, db_path_list


def sort_results(list_of_dicts):
    return sorted(list_of_dicts, key=lambda x: x["sql_idx"])


def print_data(score_lists, count_lists, metric="F1 Score", result_log_file=None):
    levels = ["simple", "moderate", "challenging", "total"]
    print("{:20} {:20} {:20} {:20} {:20}".format("", *levels))
    print("{:20} {:<20} {:<20} {:<20} {:<20}".format("count", *count_lists))

    print(
        f"======================================    {metric}    ====================================="
    )
    print("{:20} {:<20.2f} {:<20.2f} {:<20.2f} {:<20.2f}".format(metric, *score_lists))

    # Log to file in append mode
    if result_log_file is not None:
        Path(result_log_file).parent.mkdir(parents=True, exist_ok=True)
        with open(result_log_file, "a") as log_file:
            log_file.write(f"start calculate {metric}\n")
            log_file.write("{:20} {:20} {:20} {:20} {:20}\n".format("", *levels))
            log_file.write(
                "{:20} {:<20} {:<20} {:<20} {:<20}\n".format("count", *count_lists)
            )
            log_file.write(
                f"======================================    {metric}   =====================================\n"
            )
            log_file.write(
                "{:20} {:<20.2f} {:<20.2f} {:<20.2f} {:<20.2f}\n".format(
                    metric, *score_lists
                )
            )
            log_file.write(
                "===========================================================================================\n"
            )
            log_file.write(f"Finished {metric} evaluation for mini dev set\n")
            log_file.write("\n")

mod args;
mod client;
mod json;
mod orchestrator;
mod report;

use args::ClientArgs;
use orchestrator::EngineBinary;

fn main() {
    let arguments: Vec<String> = std::env::args().collect();
    match arguments.get(1).map(String::as_str) {
        Some("client") => {
            let args = ClientArgs::parse(&arguments[2..]);
            let report = client::run(args);
            println!("{}", report.to_json());
        }
        Some("run") => {
            let mut mtprotokit: Option<String> = None;
            let mut suite_name = "quick".to_string();
            let mut include_real = false;
            let mut out: Option<String> = None;
            let mut only: Option<String> = None;
            let mut repeat = 1usize;
            let mut iter = arguments[2..].iter();
            while let Some(flag) = iter.next() {
                match flag.as_str() {
                    "--mtprotokit" => mtprotokit = iter.next().cloned(),
                    "--suite" => suite_name = iter.next().cloned().expect("suite"),
                    "--real" => include_real = true,
                    "--out" => out = iter.next().cloned(),
                    "--only" => only = iter.next().cloned(),
                    "--repeat" => repeat = iter.next().and_then(|v| v.parse().ok()).expect("repeat"),
                    other => panic!("unknown argument {other}"),
                }
            }
            let mut engines =
                vec![EngineBinary { label: "rust".into(), path: arguments[0].clone(), prefix: vec!["client".into()] }];
            if let Some(path) = mtprotokit {
                engines.push(EngineBinary { label: "mtprotokit".into(), path, prefix: Vec::new() });
            }
            let mut results = Vec::new();
            let scenarios = orchestrator::suite(&suite_name, include_real);
            for (index, scenario) in scenarios.iter().enumerate() {
                if let Some(filter) = &only
                    && !scenario.name.contains(filter.as_str())
                {
                    continue;
                }
                for round in 0..repeat {
                    for engine in &engines {
                        eprintln!(
                            "[{}/{}] {} — {} (round {})",
                            index + 1,
                            scenarios.len(),
                            scenario.name,
                            engine.label,
                            round + 1
                        );
                        let result = orchestrator::run(scenario, engine, 1000 + index as u64 * 7 + round as u64);
                        eprintln!(
                            "{}",
                            orchestrator::markdown(std::slice::from_ref(&result)).lines().nth(2).unwrap_or("")
                        );
                        results.push(result);
                    }
                }
            }
            let table = orchestrator::markdown(&results);
            println!("{table}");
            if let Some(path) = out {
                std::fs::write(format!("{path}.md"), &table).expect("write markdown");
                std::fs::write(format!("{path}.json"), orchestrator::json(&results)).expect("write json");
            }
        }
        _ => {
            eprintln!(
                "usage: mtproto-bench client <args> | mtproto-bench run [--mtprotokit PATH] [--suite quick|full] [--real] [--only NAME] [--repeat N] [--out PREFIX]"
            );
            std::process::exit(2);
        }
    }
}

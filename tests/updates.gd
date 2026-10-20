extends SceneTree
const U=preload("res://scripts/application_update.gd")
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
	if ok:passed+=1;print("PASS "+text)
	else:failed+=1;push_error("FAIL "+text)
func package(path: String,pack: String,version: String="1.0.1") -> Dictionary:
	var payload=FileAccess.get_file_as_bytes(pack)
	var manifest={"format":1,"application":"Hearthtable Lite","version":version,"minimum_base":"1.0.0","engine":"4.5.1","boot_api":1,"protocol":11,"schema":1,"commit":"a".repeat(40),"pack_size":payload.size(),"sha256":FileAccess.get_sha256(pack),"changes":["Synthetic code-update validation"]}
	var encoded=JSON.stringify(manifest).to_utf8_buffer();var file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(U.MAGIC.to_ascii_buffer());file.store_32(encoded.size());file.store_buffer(encoded);file.store_buffer(payload);file.close();return manifest
func official(inspected: Dictionary) -> Dictionary:
	return {"draft":false,"tag_name":"lite-v"+inspected.manifest.version,"assets":[{"name":U.asset_name(inspected.manifest.version),"state":"uploaded","digest":"sha256:"+inspected.digest}]}
func run():
	await process_frame
	ProjectSettings.set_setting("application/config/version","1.0.0")
	var w=root.get_node("World");w.command("new_campaign",{"title":"Updater save sentinel","heroes":false});w.save_campaign();var sentinel=FileAccess.get_file_as_string(w.SAVE_PATH)
	var file=FileAccess.open("user://payload.gd",FileAccess.WRITE);file.store_string("extends RefCounted\nfunc updated_value():return 42\n");file.close()
	var pack=PCKPacker.new();check(pack.pck_start("user://fixture.pck")==OK and pack.add_file("res://synthetic_update.gd","user://payload.gd")==OK and pack.flush()==OK,"Fixture contains executable application code in a Godot resource pack")
	var manifest=package("user://fixture.hearthupdate","user://fixture.pck");var inspected=U.inspect("user://fixture.hearthupdate")
	check(inspected.ok and inspected.manifest.version=="1.0.1","Inspector parses a complete update and verifies its payload hash")
	var release=official(inspected)
	check(U.official(inspected,release),"Official asset digest and exact version establish release provenance")
	var bad=release.duplicate(true);bad.assets[0].digest="sha256:"+"0".repeat(64);check(not U.official(inspected,bad),"Mismatched published digest is refused")
	bad=release.duplicate(true);bad.draft=true;check(not U.official(inspected,bad),"Unpublished drafts cannot be installed")
	bad=release.duplicate(true);bad.tag_name="v0.99.0";check(not U.official(inspected,bad),"A different release tag cannot authorize the file")
	bad=release.duplicate(true);bad.assets[0].name="different.hearthupdate";check(not U.official(inspected,bad),"Unexpected asset names cannot authorize an update")
	check(not U.install(inspected,bad,"1.0.0","1.0.0").ok and U.read_state().active.is_empty(),"Unverified code is never staged or activated")
	check(not U.compatible(manifest,"0.11.1","0.11.1").is_empty(),"Older updater foundations require a new portable EXE")
	check(not U.compatible(manifest,"1.0.0","1.1.0").is_empty(),"Imports cannot silently downgrade a newer running version")
	check(U.compatible(manifest,"1.0.0","1.0.0").is_empty(),"A compatible newer update is allowed")
	var installed=U.install(inspected,release,"1.0.0","1.0.0","user://backup.json")
	check(installed.ok and U.read_state().pending and not U.read_state().attempted,"Installation stages a verified update pending a restart")
	check(FileAccess.get_sha256(U.pack_path(U.read_state().active))==manifest.sha256,"Installed resources match the reviewed manifest")
	check(FileAccess.get_file_as_string(w.SAVE_PATH)==sentinel,"Installing code never rewrites the existing campaign")
	check(not U.install(inspected,release,"1.0.0","1.0.0").ok,"A pending update must be restarted or canceled before another install")
	var boot=U.boot();check(boot.has("active") and U.read_state().attempted,"Boot mounts staged resources and records the unconfirmed attempt")
	var module=load("res://synthetic_update.gd").new();check(module.updated_value()==42,"Imported application code actually runs after mounting")
	U.confirm_boot();check(not U.read_state().pending and not U.active_pack().is_empty(),"Only a successful startup marks the update healthy")
	var running=U.read_state();var boot_node=root.get_node("UpdateBoot");var original_status=boot_node.status.duplicate(true);boot_node.status.active=running.active.duplicate(true);running.pending=true;U.save_state(running)
	check(U.active_pack()==U.pack_path(running.active),"Portable copies keep the mounted code version while another update is pending")
	running.pending=false;U.save_state(running);boot_node.status=original_status
	check(not U.install(inspected,release,"1.0.0","1.0.1").ok and U.read_state().active.digest==inspected.digest,"Reimporting an installed pack does not overwrite a running pack or its rollback selection")
	check(U.rollback()==OK and U.read_state().active.is_empty(),"Rollback restores the built-in version when no older package exists")
	U.install(inspected,release,"1.0.0","1.0.0");var state=U.read_state();state.attempted=true;U.save_state(state);boot=U.boot()
	check(not boot.notice.is_empty() and U.read_state().active.is_empty(),"An interrupted startup automatically rolls back on the next launch")
	U.install(inspected,release,"1.0.0","1.0.0");var path=U.pack_path(U.read_state().active);file=FileAccess.open(path,FileAccess.WRITE);file.store_string("damaged");file.close();boot=U.boot()
	check(not boot.notice.is_empty() and U.read_state().active.is_empty(),"A damaged installed pack falls back before executing any of its code")
	package("user://changed.hearthupdate","user://fixture.pck");var changed=U.inspect("user://changed.hearthupdate");file=FileAccess.open("user://changed.hearthupdate",FileAccess.READ_WRITE);file.seek(file.get_length()-1);file.store_8(43);file.close()
	check(not U.inspect("user://changed.hearthupdate").ok and not U.install(changed,official(changed),"1.0.0","1.0.0").ok,"Changed or corrupted files are rejected after review as well as on initial import")
	file=FileAccess.open("user://truncated.hearthupdate",FileAccess.WRITE);file.store_buffer(U.MAGIC.to_ascii_buffer());file.store_32(4000000000);file.close();check(not U.inspect("user://truncated.hearthupdate").ok,"Untrusted header lengths are bounded before reading payloads")
	bad=manifest.duplicate(true);bad.version="../../other";check(not U.manifest_valid(bad),"Versions cannot contain paths or redirects")
	bad=manifest.duplicate(true);bad.application="Hearthtable";check(not U.manifest_valid(bad),"Classic Hearthtable updates cannot be installed into Lite")
	bad=manifest.duplicate(true);bad.engine="4.6.3";check(not U.manifest_valid(bad),"Mismatched engine packs are refused")
	bad=manifest.duplicate(true);bad.pack_size=U.MAX_PACK+1;check(not U.manifest_valid(bad),"Oversized update payloads are refused")
	bad=manifest.duplicate(true);bad.changes=[{"code":"arbitrary"}];check(not U.manifest_valid(bad),"Change descriptions must be bounded text")
	check(FileAccess.get_file_as_string(w.SAVE_PATH)==sentinel,"Failed imports and rollback retain the campaign byte-for-byte")
	U.save_state({});print("UPDATES_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
